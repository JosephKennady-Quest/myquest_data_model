"""
Builds mat_learning_activity by joining fact_lesson_progress with the
dim_placement_learner and dim_subject dimensions — all three tables live in
the destination DB (myquest_data_model), so this is a single-connection
query, unlike fact_lesson_progress.py.

Must run after BOTH:
  1. main.py (builds dim_placement_learner, dim_subject, ...)
  2. python_query/fact_lesson_progress.py (builds fact_lesson_progress)

Typical invocation:
    python main.py --full-refresh \
        && python python_query/fact_lesson_progress.py \
        && python python_query/mat_learning_activity.py
"""

import sys
from pathlib import Path

# Allow running this script directly (e.g. `python python_query/mat_learning_activity.py`)
# without the repo root being on sys.path.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pandas as pd
import pymysql

from config import ANALYTICS_DB, QUERY_FETCH_CHUNK_SIZE
from db import _connect, _write_with_conn

TABLE_NAME = "mat_learning_activity"

SELECT_SQL = """
SELECT
    flp.activity_id,
    flp.user_id,
    flp.subject_id,
    flp.lesson_id,
    flp.course_id,
    flp.lesson_name,
    flp.lesson_order,
    flp.is_assessment,
    flp.score,
    flp.rating,
    flp.duration,
    flp.created_at,
    flp.completed,
    flp.completed_at,
    dlp.educational_qualification,
    dlp.gender,
    dlp.centre_name,
    dlp.centre_type,
    dlp.learner_type,
    dlp.centre_state,
    ds.subject_name
FROM fact_lesson_progress flp
LEFT JOIN dim_placement_learner dlp
    ON dlp.learner_id = flp.user_id
LEFT JOIN dim_subject ds
    ON ds.subject_id = flp.subject_id
"""


def run() -> int:
    total_rows = 0
    first_chunk = True

    # Two separate connections to the same database: MySQL doesn't allow a new
    # query on a connection while an unbuffered (SSCursor) result set from an
    # earlier query is still being streamed, so reads and writes can't share one.
    with _connect(ANALYTICS_DB) as read_conn, _connect(ANALYTICS_DB) as write_conn:
        with read_conn.cursor(pymysql.cursors.SSCursor) as cur:
            cur.execute(SELECT_SQL)
            columns = [d[0] for d in cur.description]

            while True:
                rows = cur.fetchmany(QUERY_FETCH_CHUNK_SIZE)
                if not rows:
                    break

                df = pd.DataFrame(rows, columns=columns)
                total_rows += len(df)

                write_mode = "replace" if first_chunk else "append"
                _write_with_conn(write_conn, df, TABLE_NAME, if_exists=write_mode, db_name=ANALYTICS_DB["db"]["database"])
                print(f"Wrote chunk: {len(df)} rows (total {total_rows})")
                first_chunk = False

    print(f"Done. Total rows written to {TABLE_NAME}: {total_rows}")
    return total_rows


if __name__ == "__main__":
    run()
