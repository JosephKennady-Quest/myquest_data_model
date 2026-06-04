import logging
import select
import socket
import threading
import time
from contextlib import contextmanager
from typing import Any, Dict, Iterator, Optional, Tuple

import pandas as pd
import paramiko
import pymysql

from config import CHUNK_SIZE

log = logging.getLogger(__name__)


# ── Local port forwarder ──────────────────────────────────────────────────────

def _bridge(local_sock: socket.socket, channel: paramiko.Channel) -> None:
    """Bidirectional copy between a local TCP socket and a paramiko channel."""
    while True:
        try:
            r, _, x = select.select([local_sock, channel], [], [local_sock, channel], 1.0)
            if x:
                break
            if local_sock in r:
                data = local_sock.recv(4096)
                if not data:
                    break
                channel.sendall(data)
            if channel in r:
                data = channel.recv(4096)
                if not data:
                    break
                local_sock.sendall(data)
        except Exception:
            break
    try:
        local_sock.close()
    except Exception:
        pass
    try:
        channel.close()
    except Exception:
        pass


@contextmanager
def _tunnel(ssh: Dict[str, Any]):
    """
    Open an SSH connection and spin up a local TCP server that forwards
    each accepted connection to the RDS endpoint via a direct-tcpip channel.

    Yields an object with a local_bind_port attribute so callers can connect
    pymysql to 127.0.0.1:<local_bind_port>.
    """
    # ── 1. Connect to bastion (retry on transient reset) ──────────────────────
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    for _attempt in range(1, 5):
        try:
            client.connect(
                hostname=ssh["host"],
                port=ssh["port"],
                username=ssh["username"],
                key_filename=ssh["pkey_path"],
            )
            break
        except (paramiko.ssh_exception.SSHException, ConnectionResetError, OSError) as exc:
            if _attempt == 4:
                raise
            wait = 2 ** _attempt  # 2, 4, 8 seconds
            log.warning("SSH connect attempt %d failed (%s) — retrying in %ds", _attempt, exc, wait)
            time.sleep(wait)
    log.debug("SSH connected → %s@%s", ssh["username"], ssh["host"])

    transport = client.get_transport()
    transport.set_keepalive(30)  # send keepalive every 30s to prevent idle-drop on long fetches

    # ── 2. Bind a free local port ─────────────────────────────────────────────
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind(("127.0.0.1", 0))
    local_port = server_sock.getsockname()[1]
    server_sock.listen(5)
    server_sock.settimeout(1.0)

    # ── 3. Forwarding thread ─────────────────────────────────────────────────
    stop = threading.Event()

    def _serve():
        while not stop.is_set():
            try:
                conn_sock, _ = server_sock.accept()
            except socket.timeout:
                continue
            except Exception:
                break
            try:
                ch = transport.open_channel(
                    "direct-tcpip",
                    (ssh["remote_bind_address"], ssh["remote_bind_port"]),
                    ("127.0.0.1", 0),
                )
            except Exception as e:
                log.warning("Could not open channel: %s", e)
                conn_sock.close()
                continue
            threading.Thread(target=_bridge, args=(conn_sock, ch), daemon=True).start()

    threading.Thread(target=_serve, daemon=True).start()
    log.debug("Local forwarder listening on 127.0.0.1:%d → %s:%d",
              local_port, ssh["remote_bind_address"], ssh["remote_bind_port"])

    class _Tunnel:
        local_bind_port = local_port

    try:
        yield _Tunnel()
    finally:
        stop.set()
        server_sock.close()
        client.close()
        log.debug("SSH disconnected ← %s", ssh["host"])


# ── MySQL connection through the tunnel ───────────────────────────────────────

@contextmanager
def _connect(cfg: Dict[str, Any]):
    """
    Open an SSH tunnel, then connect pymysql to the forwarded local port.

    cfg shape:
        {
          "ssh": { host, port, username, pkey_path,
                   remote_bind_address, remote_bind_port },
          "db":  { user, password, database }
        }
    """
    with _tunnel(cfg["ssh"]) as tunnel:
        conn = pymysql.connect(
            host="127.0.0.1",
            port=tunnel.local_bind_port,
            user=cfg["db"]["user"],
            password=cfg["db"]["password"],
            database=cfg["db"]["database"],
            charset="utf8mb4",
            connect_timeout=30,
            read_timeout=3600,   # allow up to 1h for large streaming queries
            write_timeout=3600,
        )
        try:
            yield conn
        finally:
            conn.close()


# ── Public helpers ────────────────────────────────────────────────────────────

def fetch(cfg: Dict[str, Any], sql: str, params: Optional[Tuple] = None) -> pd.DataFrame:
    """
    Run a SELECT through an SSH tunnel and return a DataFrame.

    Uses cursor.execute() directly to avoid the pandas SQLAlchemy warning
    when passing a raw pymysql connection.

    Args:
        cfg:    Config dict with 'ssh' and 'db' sub-dicts (SOURCE_DB or ANALYTICS_DB).
        sql:    Query string with %s placeholders.
        params: Tuple of parameter values matching %s placeholders.
    """
    with _connect(cfg) as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params or ())
            columns = [d[0] for d in cur.description]
            rows    = cur.fetchall()
    df = pd.DataFrame(rows, columns=columns)
    log.debug("fetch → %d rows", len(df))
    return df


def fetch_chunks(
    cfg: Dict[str, Any],
    sql: str,
    params: Optional[Tuple] = None,
    chunk_size: int = CHUNK_SIZE,
) -> Iterator[pd.DataFrame]:
    """
    Run a SELECT through an SSH tunnel and yield DataFrames in batches.

    This uses a server-side cursor so large result sets are streamed instead of
    loaded into memory all at once. The cursor, DB connection, SSH tunnel, and
    sockets are closed when iteration finishes or if an exception is raised.
    """
    if chunk_size <= 0:
        raise ValueError("chunk_size must be greater than 0")

    with _connect(cfg) as conn:
        with conn.cursor(pymysql.cursors.SSCursor) as cur:
            cur.execute(sql, params or ())
            columns = [d[0] for d in cur.description]
            while True:
                rows = cur.fetchmany(chunk_size)
                if not rows:
                    break
                yield pd.DataFrame(rows, columns=columns)


def delete_user_rows(
    cfg:      Dict[str, Any],
    table:    str,
    user_ids: list,
) -> None:
    """
    Delete all rows for the given user_ids from a table.
    Used by incremental runs to remove stale data before re-inserting.
    Safe to call when the table does not yet exist (no-op in that case).
    """
    if not user_ids:
        return
    ph = ", ".join(["%s"] * len(user_ids))
    with _connect(cfg) as conn:
        with conn.cursor() as cur:
            try:
                cur.execute(
                    f"DELETE FROM `{table}` WHERE user_id IN ({ph})",
                    tuple(user_ids),
                )
            except pymysql.err.ProgrammingError as exc:
                if exc.args[0] == 1146:   # table doesn't exist yet — nothing to delete
                    return
                raise
        conn.commit()
    log.debug("delete_user_rows → %s (%d user_ids)", table, len(user_ids))


def fetch_updated_ids(
    cfg: Dict[str, Any],
    source_table: str,
    id_col: str,
    updated_at_col: str,
    since_ts: str,
) -> list:
    """Return distinct IDs from source_table where updated_at_col > since_ts."""
    sql = (
        f"SELECT DISTINCT `{id_col}` FROM {source_table} "
        f"WHERE `{updated_at_col}` > %s"
    )
    with _connect(cfg) as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (since_ts,))
            rows = cur.fetchall()
    ids = [r[0] for r in rows]
    log.debug("fetch_updated_ids → %d ids from %s since %s", len(ids), source_table, since_ts)
    return ids


def delete_rows_by_ids(
    cfg: Dict[str, Any],
    table: str,
    id_col: str,
    ids: list,
) -> None:
    """Delete rows from destination table where id_col is in ids."""
    if not ids:
        return
    ph = ", ".join(["%s"] * len(ids))
    with _connect(cfg) as conn:
        with conn.cursor() as cur:
            try:
                cur.execute(f"DELETE FROM `{table}` WHERE `{id_col}` IN ({ph})", tuple(ids))
            except pymysql.err.ProgrammingError as exc:
                if exc.args[0] == 1146:  # table doesn't exist yet — nothing to delete
                    return
                raise
        conn.commit()
    log.debug("delete_rows_by_ids → removed %d ids from %s", len(ids), table)


def _delete_rows_by_ids_conn(conn, table: str, id_col: str, ids: list) -> None:
    """delete_rows_by_ids using an already-open connection."""
    if not ids:
        return
    ph = ", ".join(["%s"] * len(ids))
    with conn.cursor() as cur:
        try:
            cur.execute(f"DELETE FROM `{table}` WHERE `{id_col}` IN ({ph})", tuple(ids))
        except pymysql.err.ProgrammingError as exc:
            if exc.args[0] == 1146:
                return
            raise
    conn.commit()
    log.debug("delete_rows_by_ids → removed %d ids from %s", len(ids), table)



_DTYPE_TO_MYSQL = {
    "object":         "TEXT",
    "string":         "TEXT",
    "int8":           "TINYINT",
    "int16":          "SMALLINT",
    "int32":          "INT",
    "int64":          "BIGINT",
    "Int8":           "TINYINT",
    "Int16":          "SMALLINT",
    "Int32":          "INT",
    "Int64":          "BIGINT",
    "float32":        "FLOAT",
    "float64":        "DOUBLE",
    "Float32":        "FLOAT",
    "Float64":        "DOUBLE",
    "bool":           "TINYINT(1)",
    "boolean":        "TINYINT(1)",
    "datetime64[ns]": "DATETIME",
}


def _create_table_sql(table: str, df: pd.DataFrame) -> str:
    """Generate CREATE TABLE SQL inferred from a DataFrame's dtypes."""
    col_defs = ", ".join(
        f"`{col}` {_DTYPE_TO_MYSQL.get(str(dtype), 'TEXT')}"
        for col, dtype in df.dtypes.items()
    )
    return f"CREATE TABLE IF NOT EXISTS `{table}` ({col_defs})"


def _write_with_conn(
    conn,
    df: pd.DataFrame,
    table: str,
    if_exists: str = "replace",
    db_name: str = "",
) -> None:
    """Write a DataFrame using an already-open pymysql connection (no tunnel management)."""
    if df.empty:
        log.warning("write_table called with empty DataFrame — skipping %s", table)
        return

    df = df.astype(object).where(pd.notnull(df), other=None)

    cols         = list(df.columns)
    cols_sql     = ", ".join(f"`{c}`" for c in cols)
    placeholders = ", ".join(["%s"] * len(cols))
    insert_sql   = f"INSERT INTO `{table}` ({cols_sql}) VALUES ({placeholders})"
    rows         = [tuple(row) for row in df.itertuples(index=False, name=None)]

    with conn.cursor() as cur:
        if if_exists == "replace":
            cur.execute(f"DROP TABLE IF EXISTS `{table}`")
            cur.execute(_create_table_sql(table, df))
            log.debug("Recreated table %s", table)

        for i in range(0, len(rows), CHUNK_SIZE):
            batch = rows[i : i + CHUNK_SIZE]
            cur.executemany(insert_sql, batch)
            log.debug("Inserted chunk %d–%d → %s", i, i + len(batch), table)

    conn.commit()
    log.info("write_table → %d rows written to %s.%s", len(rows), db_name, table)


def write_table(
    cfg: Dict[str, Any],
    df: pd.DataFrame,
    table: str,
    if_exists: str = "replace",
) -> None:
    """
    Write a DataFrame to a MySQL table through an SSH tunnel.

    Opens its own tunnel and connection. For writing multiple chunks in a loop,
    use _write_with_conn with a shared connection from _connect() instead to
    avoid opening a new tunnel per chunk.
    """
    with _connect(cfg) as conn:
        _write_with_conn(conn, df, table, if_exists=if_exists, db_name=cfg["db"]["database"])


def _fetch_updated_at_stats_conn(
    conn,
    table: str,
    updated_at_col: str = "updated_at",
) -> Tuple[Optional[str], Optional[str]]:
    """fetch_updated_at_stats using an already-open connection."""
    sql = f"SELECT MIN(`{updated_at_col}`), MAX(`{updated_at_col}`) FROM `{table}`"
    with conn.cursor() as cur:
        try:
            cur.execute(sql)
            row = cur.fetchone()
            if row:
                return (
                    str(row[0]) if row[0] is not None else None,
                    str(row[1]) if row[1] is not None else None,
                )
        except pymysql.err.ProgrammingError as exc:
            if exc.args[0] in (1146, 1054):
                return None, None
            raise
        except pymysql.err.OperationalError as exc:
            if exc.args[0] == 1054:
                return None, None
            raise
    return None, None


def fetch_updated_at_stats(
    cfg: Dict[str, Any],
    table: str,
    updated_at_col: str = "updated_at",
) -> Tuple[Optional[str], Optional[str]]:
    """Return (min_updated_at, max_updated_at) from a destination table, or (None, None) if missing."""
    with _connect(cfg) as conn:
        return _fetch_updated_at_stats_conn(conn, table, updated_at_col)


_CREATE_RUN_LOG = """
CREATE TABLE IF NOT EXISTS `pipeline_run_log` (
    `id`               INT AUTO_INCREMENT PRIMARY KEY,
    `run_at`           DATETIME NOT NULL,
    `table_name`       VARCHAR(128) NOT NULL,
    `mode`             VARCHAR(16) NOT NULL,
    `rows_written`     INT NOT NULL,
    `dry_run`          TINYINT(1) NOT NULL DEFAULT 0,
    `last_updated_at`  DATETIME,
    `latest_updated_at` DATETIME
)
"""


def _write_run_log_conn(
    conn,
    table_name: str,
    mode: str,
    rows_written: int,
    dry_run: bool,
    last_updated_at: Optional[str],
    latest_updated_at: Optional[str],
) -> None:
    """write_run_log using an already-open connection."""
    with conn.cursor() as cur:
        cur.execute(_CREATE_RUN_LOG)
        cur.execute(
            """INSERT INTO `pipeline_run_log`
               (run_at, table_name, mode, rows_written, dry_run, last_updated_at, latest_updated_at)
               VALUES (NOW(), %s, %s, %s, %s, %s, %s)""",
            (table_name, mode, rows_written, int(dry_run), last_updated_at, latest_updated_at),
        )
    conn.commit()
    log.debug("write_run_log → logged %s mode=%s rows=%d", table_name, mode, rows_written)


def write_run_log(
    cfg: Dict[str, Any],
    table_name: str,
    mode: str,
    rows_written: int,
    dry_run: bool,
    last_updated_at: Optional[str],
    latest_updated_at: Optional[str],
) -> None:
    """Insert one row into pipeline_run_log."""
    with _connect(cfg) as conn:
        _write_run_log_conn(conn, table_name, mode, rows_written, dry_run, last_updated_at, latest_updated_at)
