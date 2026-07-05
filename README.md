# MyQuest Data Model

SQL query pipeline that reads from the production MySQL source (`quest_rearch_production`) through an SSH tunnel and writes dimension and fact tables into the analytics destination database (`myquest_data_model`).

---

## Repository Structure

| Path | Purpose |
| --- | --- |
| `queries/` | One `.sql` file per destination table, run automatically by `main.py`. File stem = destination table name. |
| `docs/` | Column-level documentation, mapping notes, and business logic per query/script. |
| `domain/` | Domain knowledge docs (learning outcomes, terminology, etc.). |
| `domain/draft_query/` | Draft, withdrawn, and archived SQL query files not currently run by the pipeline — see [Draft / In Progress](#draft--in-progress). |
| `python_query/` | Standalone Python scripts for logic a single SQL file can't express (e.g. joining across the source and destination databases) or one-off utilities. **Not run automatically by `main.py`** — run separately. See [Cross-Database Python Scripts](#cross-database-python-scripts). |
| `DB_Config/` | SSH private key files (`.pem`). **Not committed — add locally.** |
| `main.py` | Pipeline entry point. Scans `queries/*.sql` only. |
| `db.py` | SSH tunnel, MySQL connection, fetch/write helpers. |
| `config.py` | Environment variable loading and shared constants. |
| `requirements.txt` | Python dependencies (`python-dotenv`, `pandas`, `paramiko`, `pymysql`). Install with `pip install -r requirements.txt`. |
| `.env.example` | Template for required environment variables. Copy to `.env` and fill in. |
| `.pipeline_state.json` | Auto-generated. Tracks last successful run timestamp per table for incremental runs. **Not committed.** |

---

## Setup

### 1. Python environment

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Environment variables

```bash
cp .env.example .env
# Fill in source and destination DB credentials, SSH host/user/key file names
```

### 3. SSH keys

Place your `.pem` key files inside `DB_Config/`. The file names must match what you set in `.env` for `SOURCE_SSH_PKEY_FILE` and `DEST_SSH_PKEY_FILE`.

---

## Running the Pipeline

### Run all queries (incremental where supported, full on first run)

```bash
python main.py
```

### Run a specific query

```bash
python main.py --query dim_batch
```

### Run multiple specific queries

```bash
python main.py --query dim_batch --query dim_centre
```

### Force a full refresh (ignore incremental state)

```bash
python main.py --full-refresh
python main.py --query dim_batch --full-refresh
```

### Dry run (read-only — counts rows, no writes)

```bash
python main.py --dry-run
python main.py --query dim_batch --dry-run
```

### Custom fetch chunk size

```bash
python main.py --chunk-size 10000
```

### Automatic retry on transient connection drops

`main.py` retries a query run with exponential backoff (up to 3 attempts) if the SSH bastion tunnel or MySQL connection drops mid-run (`CR_SERVER_LOST` and similar transient errors). This is safe because each retry re-executes the query from scratch:

- **Full runs** are only auto-retried when `--if-exists replace` (the default) — the first chunk of the retry re-`replace`s the table, safely overwriting any partial write from the failed attempt. If you explicitly pass `--if-exists append`, a transient failure is raised immediately instead of retried, to avoid duplicating rows already written.
- **Incremental runs** are always auto-retried — each attempt deletes-then-reinserts the same changed IDs, so a retry after a partial write is idempotent.

Non-transient errors (SQL syntax errors, missing tables/columns) are raised immediately without wasting retries.

---

## Running on a Schedule (cron)

To run the pipeline unattended, use `cron` on the host machine. Two things matter that don't apply when running interactively:

1. **Use the virtualenv's `python3` directly** — cron doesn't activate virtualenvs or source your shell profile, so a bare `python3` call will hit the system interpreter and fail on missing packages.
2. **`cd` into the project directory first** — `config.py` calls `load_dotenv()` with no path, which searches for `.env` starting from the current working directory. Cron's default working directory is your home directory, not the project folder.

Example crontab entry (daily at 2 AM, running the main pipeline followed by the `fact_lesson_progress` script, both logged to a file):

```cron
0 2 * * * cd "/path/to/Data Model" && "/path/to/Data Model/.venv/bin/python3" main.py --full-refresh && "/path/to/Data Model/.venv/bin/python3" python_query/fact_lesson_progress.py >> "/path/to/Data Model/logs/pipeline.log" 2>&1
```

Test the exact command manually in a shell first (not via cron) to confirm paths are correct before relying on the schedule.

---

## Incremental Runs

Queries that support incremental mode declare a header comment in the SQL file:

```sql
-- @incremental source_table=schema.table id_col=<source_pk> updated_at_col=updated_at dest_id_col=<output_col>
```

**How it works:**

1. **First run** — no state exists, runs a full `replace` and saves the current timestamp to `.pipeline_state.json`.
2. **Subsequent runs** — scans `source_table` for rows where `updated_at_col > last_run_at`, collects the changed IDs, deletes their stale rows from the destination (matched by `dest_id_col`), and re-inserts fresh data only for those IDs.
3. **`--full-refresh`** — ignores incremental state and runs a full replace regardless. Resets the saved timestamp on success.

State is stored per-table in `.pipeline_state.json` (auto-created, git-ignored).

> **`id_col` vs `dest_id_col`** — `id_col` is the primary key in the source table used to detect changes. `dest_id_col` is the matching column name in the query output (which may differ, e.g. `id` → `batch_id`).

### Queries with incremental support

| Query / Table | Source table | Source ID | Dest ID column | Updated-at column |
| --- | --- | --- | --- | --- |
| `dim_batch` | `quest_rearch_production.batches` | `id` | `batch_id` | `updated_at` |
| `dim_centre` | `quest_rearch_production.centres` | `id` | `centre_id` | `updated_at` |
| `dim_educator` | `quest_rearch_production.users` | `id` | `educator_id` | `updated_at` |
| `dim_placement_learner` | `quest_rearch_production.users` | `id` | `learner_id` | `updated_at` |
| `dim_phase` | `quest_rearch_production.phases` | `id` | `phase_id` | `updated_at` |
| `dim_program` | `quest_rearch_production.programs` | `id` | `program_id` | `updated_at` |
| `dim_project` | `quest_rearch_production.projects` | `id` | `project_id` | `updated_at` |
| `dim_subject` | `quest_rearch_production.subjects` | `id` | `subject_id` | `updated_at` |
| `fact_centre_visit` | `quest_rearch_production.mqops_centre_visits` | `id` | `centre_visit_id` | `updated_at` |
| `fact_ple_response` | `quest_rearch_production.ple_assessment_responses` | `id` | `response_id` | `updated_at` |
| `fact_session` | `quest_rearch_production.mqops_session_trackers` | `id` | `id` | `created_at` |
| `fact_placement` | `quest_rearch_production.placements` | `id` | `placement_id` | `updated_at` |
| `fact_tot_session` | `quest_rearch_production.mqops_tot_summary` | `id` | `tot_summary_id` | `updated_at` |

> `fact_learning_event` and `fact_skill_scores` were withdrawn from `queries/` back to `domain/draft_query/` for rework — see [Draft / In Progress](#draft--in-progress). `dim_geography` has no `@incremental` header yet and always runs as a full replace.

---

## Destination-Only Queries

Queries that read from tables already in `myquest_data_model` (rather than the production source) declare the following header:

```sql
-- @dest_only
```

**How it works:**

The pipeline detects this flag and connects to `ANALYTICS_DB` (destination) instead of `SOURCE_DB` (production source) when fetching rows. This is used for queries that transform or roll up tables that were previously written to the analytics DB by an earlier pipeline step.

### Queries with `@dest_only`

| Query / Table | Source table (in analytics DB) | Description |
| --- | --- | --- |
| `fact_subject_progress` | `quest_analytics.production_users_one_record`, `quest_analytics.user_addon` | Per-learner, per-subject progress unnested from a JSON column via `JSON_TABLE`, enriched with display attributes |

> `fact_lesson_progress` is **not** a `@dest_only` query file — it needs data from both the source and destination databases at once, which no single SQL connection can join. See [Cross-Database Python Scripts](#cross-database-python-scripts).

---

## Run Logs

Every successful run appends a row to the `pipeline_run_log` table in the analytics database. The table is auto-created on first run.

| Column | Description |
| --- | --- |
| `run_at` | Timestamp when the pipeline ran |
| `table_name` | Destination table name |
| `mode` | `full` or `incremental` |
| `rows_written` | Number of records stored this run |
| `dry_run` | `1` if `--dry-run` was used, otherwise `0` |
| `last_updated_at` | Oldest `updated_at` in the destination table before the run |
| `latest_updated_at` | Newest `updated_at` in the destination table after the run |

---

## Adding a New Query

1. Create `queries/<table_name>.sql` with your SELECT.
2. Add the SQL header block at the top:
   ```sql
   -- @incremental source_table=schema.main_table id_col=<source_pk> updated_at_col=updated_at dest_id_col=<output_id_col>
   -- ─────────────────────────────────────────────────────────────────────────────
   -- Table    : <table_name>
   -- Grain    : <one line grain description>
   -- Mode     : incremental / full / full (dest_only)
   -- Source   : <source tables, comma-separated>
   -- Docs     : docs/<table_name>.md
   -- ─────────────────────────────────────────────────────────────────────────────
   ```
   - Use `-- @incremental ...` if the query supports incremental runs from the production source.
   - Use `-- @dest_only` instead if the query reads from a table already in the analytics destination DB.
   - `dest_id_col` must match the column name **in the query output** (the alias in your SELECT), not the source table column name.
3. Create `docs/<table_name>.md` following the documentation standard below.

---

## Cross-Database Python Scripts

Some tables need data from **both** the source and destination databases at once — for example, a set of IDs already computed in the destination that must drive a filter on the production source. No single SQL connection can `JOIN` across two separate database servers, so these can't be expressed as a `queries/*.sql` file.

For this case, write a standalone script under `python_query/` instead. `python_query/fact_lesson_progress.py` is the reference example — see [docs/fact_lesson_progress.md](docs/fact_lesson_progress.md) for the full walkthrough. The pattern:

1. Fetch the driving set of keys from the destination DB with `fetch()` (from `db.py`).
2. Open one connection to the source DB with `_connect()`, load the keys into a `CREATE TEMPORARY TABLE`, and `JOIN` against it in a single query — far cheaper than one round trip per key.
3. Stream the result in chunks (`SSCursor` + `fetchmany`) and write each chunk to the destination with `_write_with_conn`, reusing one persistent connection for the whole run (the same pattern `main.py` uses, to avoid opening a new SSH tunnel per chunk).

**Important:** these scripts are **not** picked up by `main.py` — it only scans `.sql` files in `queries/`. Run them explicitly, e.g.:

```bash
python main.py --full-refresh && python python_query/fact_lesson_progress.py
```

Each script should also insert the repo root onto `sys.path` before importing `config`/`db`, so it works regardless of the current working directory it's invoked from:

```python
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
```

---

## Current Models

### Dimensions

| Model | Grain | Query | Documentation |
| --- | --- | --- | --- |
| `dim_batch` | One row per batch-trade combination | [queries/dim_batch.sql](queries/dim_batch.sql) | [docs/dim_batch_query_columns.md](docs/dim_batch_query_columns.md) |
| `dim_centre` | One row per centre | [queries/dim_centre.sql](queries/dim_centre.sql) | [docs/dim_centre.md](docs/dim_centre.md) |
| `dim_educator` | One row per educator | [queries/dim_educator.sql](queries/dim_educator.sql) | [docs/dim_educator.md](docs/dim_educator.md) |
| `dim_geography` | One row per centre (centre-state-district lookup) | [queries/dim_geography.sql](queries/dim_geography.sql) | [docs/dim_geography.md](docs/dim_geography.md) |
| `dim_phase` | One row per phase | [queries/dim_phase.sql](queries/dim_phase.sql) | [docs/dim_phase.md](docs/dim_phase.md) |
| `dim_placement_learner` | One row per learner | [queries/dim_placement_learner.sql](queries/dim_placement_learner.sql) | [docs/dim_placement_learner_query_columns.md](docs/dim_placement_learner_query_columns.md) |
| `dim_program` | One row per program | [queries/dim_program.sql](queries/dim_program.sql) | [docs/dim_program.md](docs/dim_program.md) |
| `dim_project` | One row per project | [queries/dim_project.sql](queries/dim_project.sql) | [docs/dim_project.md](docs/dim_project.md) |
| `dim_subject` | One row per subject | [queries/dim_subject.sql](queries/dim_subject.sql) | [docs/dim_subject.md](docs/dim_subject.md) |

### Facts

| Model | Grain | Query | Documentation |
| --- | --- | --- | --- |
| `fact_centre_visit` | One row per centre visit-centre-related user combination | [queries/fact_centre_visit.sql](queries/fact_centre_visit.sql) | [docs/fact_centre_visit.md](docs/fact_centre_visit.md) |
| `fact_lesson_progress` | One row per completed learning activity for a known learner-subject pair | [python_query/fact_lesson_progress.py](python_query/fact_lesson_progress.py) — cross-database script, not a `queries/*.sql` file | [docs/fact_lesson_progress.md](docs/fact_lesson_progress.md) |
| `fact_ple_response` | One row per PLE assessment response | [queries/fact_ple_response.sql](queries/fact_ple_response.sql) | [docs/fact_ple_response.md](docs/fact_ple_response.md) |
| `fact_session` | One row per session tracker record | [queries/fact_session.sql](queries/fact_session.sql) | [docs/fact_session.md](docs/fact_session.md) |
| `fact_subject_progress` | One row per learner-subject combination | [queries/fact_subject_progress.sql](queries/fact_subject_progress.sql) | [docs/fact_subject_progress.md](docs/fact_subject_progress.md) |
| `fact_placement` | One row per learner per placement type (3 types via UNION ALL) | [queries/fact_placement.sql](queries/fact_placement.sql) | [docs/fact_placement.md](docs/fact_placement.md) |
| `fact_tot_session` | One row per ToT summary-centre/stakeholder row | [queries/fact_tot_session.sql](queries/fact_tot_session.sql) | [docs/fact_tot_session.md](docs/fact_tot_session.md) |

### Draft / In Progress

All draft, withdrawn, and superseded query files live in `domain/draft_query/`.

| File | Status |
| --- | --- |
| `draft_fact_course_progress.sql` | Draft / exploratory — not yet promoted to `queries/`. |
| `draft_fact_learning_event.sql` | Withdrawn from `queries/fact_learning_event.sql` for rework. Previously live — see [docs/fact_learning_event.md](docs/fact_learning_event.md) for the last-known-good version's documentation. |
| `draft_fact_lesson_progress.sql` | Superseded — `fact_lesson_progress` is now built by [python_query/fact_lesson_progress.py](python_query/fact_lesson_progress.py) instead (see [Cross-Database Python Scripts](#cross-database-python-scripts)). Kept for reference only. |
| `draft_fact_skill_scores.sql` | Withdrawn from `queries/fact_skill_scores.sql` for rework. Previously live — see [docs/fact_skill_scores.md](docs/fact_skill_scores.md) for the last-known-good version's documentation. |
| `draft_fact_subject_progress.sql` | Draft / exploratory — an earlier, simpler approach to subject progress. Superseded by the live `queries/fact_subject_progress.sql`. |
| `old_fact_subject_progress.sql` | Previous version of `fact_subject_progress`, kept for reference. |
| `archive_fact_lesson_progress.sql` | Archived version of an earlier `fact_lesson_progress` implementation, kept for reference. |

---

## Documentation Standard

Each query doc in `docs/` covers:

- **Query Grain** — what one row represents and any fan-out risks
- **Incremental Configuration** — source table, ID columns, updated-at column (or `@dest_only` note)
- **Global Filters** — all WHERE conditions with business reason
- **Output Columns** — source table, source column, transform logic, nullability
- **Entity Relationship Diagram** — Mermaid ERD of all joined source tables
- **Join and Cardinality Notes** — join type and expected row-count effect per join
- **DWH Interpretation** — intended target table, grain risks, source schema status
