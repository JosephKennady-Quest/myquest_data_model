# MyQuest Data Model

SQL query pipeline that reads from the production MySQL source (`quest_rearch_production`) through an SSH tunnel and writes dimension/fact tables into the analytics destination database (`quest_ple_analytics`).

---

## Repository Structure

| Path | Purpose |
| --- | --- |
| `queries/` | One `.sql` file per destination table. File stem = destination table name. |
| `docs/` | Column-level documentation, mapping notes, and business logic per query. |
| `domain/` | Domain knowledge docs (learning outcomes, terminology, etc.). |
| `DB_Config/` | SSH private key files (`.pem`). **Not committed — add locally.** |
| `main.py` | Pipeline entry point. |
| `db.py` | SSH tunnel, MySQL connection, fetch/write helpers. |
| `config.py` | Environment variable loading and shared constants. |
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

---

## Incremental Runs

Queries that support incremental mode declare a header comment in the SQL file:

```sql
-- @incremental source_table=schema.table id_col=<pk_col> updated_at_col=updated_at
```

**How it works:**

1. **First run** — no state exists, runs a full `replace` and saves the current timestamp to `.pipeline_state.json`.
2. **Subsequent runs** — scans `source_table` for rows where `updated_at_col > last_run_at`, collects the changed IDs, deletes their stale rows from the destination, and re-inserts fresh data only for those IDs.
3. **`--full-refresh`** — ignores incremental state and runs a full replace regardless. Resets the saved timestamp on success.

State is stored per-table in `.pipeline_state.json` (auto-created, git-ignored).

### Queries with incremental support

| Query / Table | Source table | ID column | Updated-at column |
| --- | --- | --- | --- |
| `dim_batch` | `quest_rearch_production.batches` | `batch_id` | `updated_at` |
| `dim_learner` | `quest_rearch_production.users` | `learner_id` | `updated_at` |

---

## Adding a New Query

1. Create `queries/<table_name>.sql` with your SELECT.
2. If incremental support is needed, add the header as the first non-blank line:
   ```sql
   -- @incremental source_table=schema.main_table id_col=<pk> updated_at_col=updated_at
   ```
   The `id_col` value must match a column name in the **output** of your query (not just the source table), because the pipeline wraps your query as a subquery and filters by that column.
3. Add column documentation to `docs/<table_name>_query_columns.md`.

---

## Current Models

| Model | Query | Documentation |
| --- | --- | --- |
| `dim_batch` | [queries/dim_batch.sql](queries/dim_batch.sql) | [docs/dim_batch_query_columns.md](docs/dim_batch_query_columns.md) |
| `dim_learner` | [queries/dim_learner.sql](queries/dim_learner.sql) | [docs/dim_learner_query_columns.md](docs/dim_learner_query_columns.md) |

---

## Documentation Standard

Each query doc should cover per column:

- Output column name
- Source table and source column
- Transform or business logic applied
- Reason for inclusion
- Nullability in query output
- Target DWH table and column
- Whether the source is a production table or an existing DWH table
