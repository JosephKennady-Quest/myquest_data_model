import argparse
import json
import logging
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from config import ANALYTICS_DB, QUERIES_DIR, QUERY_FETCH_CHUNK_SIZE, SOURCE_DB, _PIPELINE_DIR
from db import delete_rows_by_ids, fetch_chunks, fetch_updated_ids, fetch_updated_at_stats, write_run_log, write_table


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("query_runner")

_STATE_FILE = Path(_PIPELINE_DIR) / ".pipeline_state.json"
_INCREMENTAL_PATTERN = re.compile(
    r"--\s*@incremental\s+source_table=(\S+)\s+id_col=(\S+)\s+updated_at_col=(\S+)"
    r"(?:\s+dest_id_col=(\S+))?"
)


# ── State helpers ─────────────────────────────────────────────────────────────

def _load_state() -> dict:
    if _STATE_FILE.exists():
        return json.loads(_STATE_FILE.read_text(encoding="utf-8"))
    return {}


def _save_state(state: dict) -> None:
    _STATE_FILE.write_text(json.dumps(state, indent=2), encoding="utf-8")


def _get_last_run(table_name: str) -> Optional[str]:
    return _load_state().get(table_name, {}).get("last_run_at")


def _record_run(table_name: str) -> None:
    state = _load_state()
    state.setdefault(table_name, {})["last_run_at"] = datetime.now(timezone.utc).strftime(
        "%Y-%m-%d %H:%M:%S"
    )
    _save_state(state)


# ── Incremental config parser ─────────────────────────────────────────────────

def _parse_incremental_config(sql: str) -> Optional[dict]:
    """Return incremental config dict if the SQL has an @incremental header, else None."""
    for line in sql.splitlines():
        m = _INCREMENTAL_PATTERN.match(line.strip())
        if m:
            return {"source_table": m.group(1), "id_col": m.group(2), "updated_at_col": m.group(3), "dest_id_col": m.group(4) or m.group(2)}
    return None


# ── CLI ───────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run SQL query files from the queries folder and write each result "
            "to the destination database. By default, all queries run."
        )
    )
    parser.add_argument(
        "--query",
        action="append",
        default=None,
        help=(
            "Run only the specified query/table name. Use the file stem, for example "
            "`--query dim_batch`. Can be provided multiple times."
        ),
    )
    parser.add_argument(
        "--full-refresh",
        action="store_true",
        help="Force a full replace even when the query supports incremental runs.",
    )
    parser.add_argument(
        "--if-exists",
        choices=["replace", "append"],
        default="replace",
        help="How to write to the destination table for full runs. Default: replace.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Read and count rows, but do not write to the destination database.",
    )
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=QUERY_FETCH_CHUNK_SIZE,
        help=(
            "Rows to fetch from the source database per chunk. "
            f"Default: {QUERY_FETCH_CHUNK_SIZE}."
        ),
    )
    return parser.parse_args()


# ── Query file list ───────────────────────────────────────────────────────────

def _query_files(selected_queries: list[str] | None = None) -> list[Path]:
    queries_dir = Path(QUERIES_DIR)
    if not queries_dir.exists():
        raise FileNotFoundError(f"Queries directory does not exist: {queries_dir}")

    available = {path.stem: path for path in sorted(queries_dir.glob("*.sql"))}
    if not available:
        raise FileNotFoundError(f"No .sql query files found in: {queries_dir}")

    if not selected_queries:
        return list(available.values())

    requested = [query.removesuffix(".sql") for query in selected_queries]
    missing = [query for query in requested if query not in available]
    if missing:
        valid = ", ".join(sorted(available))
        raise ValueError(f"Unknown query/table name(s): {', '.join(missing)}. Available: {valid}")

    return [available[query] for query in requested]


# ── Run a single query file ───────────────────────────────────────────────────

def run_query_file(
    query_file: Path,
    full_refresh: bool = False,
    if_exists: str = "replace",
    dry_run: bool = False,
    chunk_size: int = QUERY_FETCH_CHUNK_SIZE,
) -> int:
    table_name = query_file.stem
    sql = query_file.read_text(encoding="utf-8")

    incremental_cfg = _parse_incremental_config(sql)
    last_run_at = _get_last_run(table_name)

    use_incremental = (
        incremental_cfg is not None
        and not full_refresh
        and last_run_at is not None
    )

    if use_incremental:
        return _run_incremental(
            query_file, sql, table_name, incremental_cfg, last_run_at, dry_run, chunk_size
        )
    else:
        reason = (
            "full-refresh flag set" if full_refresh
            else "no previous run recorded" if last_run_at is None
            else "no @incremental config"
        )
        log.info("Running %s as full replace (%s)", table_name, reason)
        return _run_full(query_file, sql, table_name, if_exists, dry_run, chunk_size)


def _run_full(
    query_file: Path,
    sql: str,
    table_name: str,
    if_exists: str,
    dry_run: bool,
    chunk_size: int,
) -> int:
    log.info("Running query %s from %s", table_name, query_file)
    last_updated_at, _ = fetch_updated_at_stats(ANALYTICS_DB, table_name)
    total_rows = 0
    first_chunk = True

    for chunk_number, df in enumerate(fetch_chunks(SOURCE_DB, sql, chunk_size=chunk_size), start=1):
        total_rows += len(df)
        log.info("Query %s chunk %d: %d rows, %d columns", table_name, chunk_number, len(df), len(df.columns))

        if dry_run:
            continue

        write_mode = if_exists if first_chunk else "append"
        write_table(ANALYTICS_DB, df, table_name, if_exists=write_mode)
        log.info("Wrote chunk %d for %s (mode=%s)", chunk_number, table_name, write_mode)
        first_chunk = False

    if total_rows == 0:
        log.warning("Query %s returned 0 rows; no destination write was performed.", table_name)
    elif dry_run:
        log.info("Dry run enabled; skipped writing %d rows for %s", total_rows, table_name)
    else:
        _record_run(table_name)
        _, latest_updated_at = fetch_updated_at_stats(ANALYTICS_DB, table_name)
        write_run_log(ANALYTICS_DB, table_name, "full", total_rows, dry_run, last_updated_at, latest_updated_at)

    log.info("Query %s complete; total rows: %d", table_name, total_rows)
    return total_rows


def _run_incremental(
    query_file: Path,
    sql: str,
    table_name: str,
    cfg: dict,
    last_run_at: str,
    dry_run: bool,
    chunk_size: int,
) -> int:
    source_table = cfg["source_table"]
    id_col = cfg["id_col"]
    updated_at_col = cfg["updated_at_col"]
    dest_id_col = cfg["dest_id_col"]

    log.info(
        "Incremental run for %s — scanning %s.%s > '%s'",
        table_name, source_table, updated_at_col, last_run_at,
    )
    last_updated_at, _ = fetch_updated_at_stats(ANALYTICS_DB, table_name)

    updated_ids = fetch_updated_ids(SOURCE_DB, source_table, id_col, updated_at_col, last_run_at)

    if not updated_ids:
        log.info("No updated records since %s — skipping %s", last_run_at, table_name)
        write_run_log(ANALYTICS_DB, table_name, "incremental", 0, dry_run, last_updated_at, last_updated_at)
        return 0

    log.info("%d updated id(s) found for %s", len(updated_ids), table_name)

    # Wrap original query and filter to only the changed IDs
    placeholders = ", ".join(["%s"] * len(updated_ids))
    incremental_sql = (
        f"SELECT * FROM ({sql}) AS _incremental_q "
        f"WHERE `{dest_id_col}` IN ({placeholders})"
    )

    total_rows = 0
    first_chunk = True

    # Dry run: just count without touching destination
    if dry_run:
        for chunk_number, df in enumerate(
            fetch_chunks(SOURCE_DB, incremental_sql, params=tuple(updated_ids), chunk_size=chunk_size),
            start=1,
        ):
            total_rows += len(df)
            log.info("Dry run chunk %d for %s: %d rows", chunk_number, table_name, len(df))
        log.info("Dry run: would have written %d rows for %s", total_rows, table_name)
        return total_rows

    # Delete stale rows then re-insert fresh data
    delete_rows_by_ids(ANALYTICS_DB, table_name, dest_id_col, updated_ids)
    log.info("Deleted stale rows for %d id(s) from %s", len(updated_ids), table_name)

    for chunk_number, df in enumerate(
        fetch_chunks(SOURCE_DB, incremental_sql, params=tuple(updated_ids), chunk_size=chunk_size),
        start=1,
    ):
        total_rows += len(df)
        write_table(ANALYTICS_DB, df, table_name, if_exists="append")
        log.info("Wrote incremental chunk %d for %s: %d rows", chunk_number, table_name, len(df))
        first_chunk = False

    if total_rows == 0:
        log.warning("Incremental query %s returned 0 rows for the updated ids.", table_name)
    else:
        _record_run(table_name)

    _, latest_updated_at = fetch_updated_at_stats(ANALYTICS_DB, table_name)
    write_run_log(ANALYTICS_DB, table_name, "incremental", total_rows, dry_run, last_updated_at, latest_updated_at)
    log.info("Incremental run for %s complete; rows written: %d", table_name, total_rows)
    return total_rows


# ── Entry point ───────────────────────────────────────────────────────────────

def run(
    selected_queries: list[str] | None = None,
    full_refresh: bool = False,
    if_exists: str = "replace",
    dry_run: bool = False,
    chunk_size: int = QUERY_FETCH_CHUNK_SIZE,
) -> None:
    if chunk_size <= 0:
        raise ValueError("chunk_size must be greater than 0")

    query_files = _query_files(selected_queries)
    log.info("Queries selected: %s", ", ".join(path.stem for path in query_files))
    log.info("Source fetch chunk size: %d rows", chunk_size)

    total_rows = 0
    for query_file in query_files:
        total_rows += run_query_file(
            query_file,
            full_refresh=full_refresh,
            if_exists=if_exists,
            dry_run=dry_run,
            chunk_size=chunk_size,
        )

    log.info("Finished %d query file(s); total rows read: %d", len(query_files), total_rows)


if __name__ == "__main__":
    args = parse_args()
    run(
        selected_queries=args.query,
        full_refresh=args.full_refresh,
        if_exists=args.if_exists,
        dry_run=args.dry_run,
        chunk_size=args.chunk_size,
    )
