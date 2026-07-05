"""
Builds fact_lesson_progress by combining two databases that no single SQL
connection can join directly:

  1. destination DB (myquest_data_model.fact_subject_progress) — the set of
     (user_id, subject_id) pairs we already track subject-level progress for.
  2. source DB (quest_rearch_production.learning_activities + lessons) — the
     completed lesson-level activity for exactly those pairs.

The pairs are loaded into a temporary table on the source connection so the
lesson-level pull is a single indexed JOIN instead of one round trip per pair.
"""

import sys
from pathlib import Path

# Allow running this script directly (e.g. `python python_query/fact_lesson_progress.py`)
# without the repo root being on sys.path.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pandas as pd
import pymysql

from config import ANALYTICS_DB, QUERY_FETCH_CHUNK_SIZE, SOURCE_DB
from db import _connect, _write_with_conn, fetch

TABLE_NAME = "fact_lesson_progress"
PAIR_INSERT_BATCH_SIZE = 5000

JOIN_SQL = """
SELECT
    la.id           AS activity_id,
    la.user_id,
    la.centre_id,
    la.subject_id,
    la.lesson_id,
    la.course_id,
    l.name          AS lesson_name,
    l.lesson_order,
    l.is_assessment,
    la.score,
    la.rating,
    la.duration,
    la.created_at,
    la.completed,
    la.completed_at
FROM tmp_user_subject_pairs p
JOIN quest_rearch_production.learning_activities la
    ON la.user_id = p.user_id AND la.subject_id = p.subject_id
JOIN quest_rearch_production.lessons l
    ON l.id = la.lesson_id
WHERE la.completed = 1
"""


def _fetch_pairs() -> list[tuple[str, str]]:
    df = fetch(
        ANALYTICS_DB,
        """
        SELECT fsp.tlo_users_id AS user_id, fsp.subject_id
        FROM myquest_data_model.fact_subject_progress AS fsp
        GROUP BY fsp.tlo_users_id, fsp.subject_id
        """,
    )
    return list(df.itertuples(index=False, name=None))


def _load_pairs_into_temp_table(conn, pairs: list[tuple[str, str]]) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TEMPORARY TABLE tmp_user_subject_pairs (
                user_id    CHAR(36) NOT NULL,
                subject_id CHAR(36) NOT NULL,
                PRIMARY KEY (user_id, subject_id)
            )
            """
        )
        insert_sql = "INSERT IGNORE INTO tmp_user_subject_pairs (user_id, subject_id) VALUES (%s, %s)"
        for start in range(0, len(pairs), PAIR_INSERT_BATCH_SIZE):
            cur.executemany(insert_sql, pairs[start : start + PAIR_INSERT_BATCH_SIZE])
    conn.commit()


def run() -> int:
    pairs = _fetch_pairs()
    print(f"Fetched {len(pairs)} distinct (user_id, subject_id) pairs from fact_subject_progress")

    total_rows = 0
    first_chunk = True

    with _connect(SOURCE_DB) as source_conn:
        _load_pairs_into_temp_table(source_conn, pairs)
        print(f"Loaded {len(pairs)} pairs into a temp table on the source DB")

        with source_conn.cursor(pymysql.cursors.SSCursor) as cur, _connect(ANALYTICS_DB) as dest_conn:
            cur.execute(JOIN_SQL)
            columns = [d[0] for d in cur.description]

            while True:
                rows = cur.fetchmany(QUERY_FETCH_CHUNK_SIZE)
                if not rows:
                    break

                df = pd.DataFrame(rows, columns=columns)
                total_rows += len(df)

                write_mode = "replace" if first_chunk else "append"
                _write_with_conn(dest_conn, df, TABLE_NAME, if_exists=write_mode, db_name=ANALYTICS_DB["db"]["database"])
                print(f"Wrote chunk: {len(df)} rows (total {total_rows})")
                first_chunk = False

    print(f"Done. Total rows written to {TABLE_NAME}: {total_rows}")
    return total_rows


if __name__ == "__main__":
    run()
