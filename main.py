import argparse
import logging
from pathlib import Path

from config import ANALYTICS_DB, QUERIES_DIR, SOURCE_DB
from db import fetch, write_table


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("query_runner")


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
        "--if-exists",
        choices=["replace", "append"],
        default="replace",
        help="How to write to the destination table. Default: replace.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Read and count rows, but do not write to the destination database.",
    )
    return parser.parse_args()


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


def run_query_file(query_file: Path, if_exists: str = "replace", dry_run: bool = False) -> int:
    table_name = query_file.stem
    sql = query_file.read_text(encoding="utf-8")

    log.info("Running query %s from %s", table_name, query_file)
    df = fetch(SOURCE_DB, sql)
    log.info("Query %s returned %d rows and %d columns", table_name, len(df), len(df.columns))

    if dry_run:
        log.info("Dry run enabled; skipping write for %s", table_name)
        return len(df)

    write_table(ANALYTICS_DB, df, table_name, if_exists=if_exists)
    log.info("Wrote %s to destination table %s", query_file.name, table_name)
    return len(df)


def run(
    selected_queries: list[str] | None = None,
    if_exists: str = "replace",
    dry_run: bool = False,
) -> None:
    query_files = _query_files(selected_queries)
    log.info("Queries selected: %s", ", ".join(path.stem for path in query_files))

    total_rows = 0
    for query_file in query_files:
        total_rows += run_query_file(query_file, if_exists=if_exists, dry_run=dry_run)

    log.info("Finished %d query file(s); total rows read: %d", len(query_files), total_rows)


if __name__ == "__main__":
    args = parse_args()
    run(selected_queries=args.query, if_exists=args.if_exists, dry_run=args.dry_run)
