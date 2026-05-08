# MyQuest Data Model

This repository stores data model queries and supporting documentation for MyQuest reporting and DWH work.

## Repository Structure

| Folder | Purpose |
| --- | --- |
| `queries/` | SQL and notebook query files used to build or validate model outputs. |
| `docs/` | Column-level documentation, mapping notes, and business logic explanations for the queries. |

## Current Models

| Model | Query | Documentation |
| --- | --- | --- |
| `dim_batch` | [queries/dim_batch.sql](queries/dim_batch.sql) | [docs/dim_batch_query_columns.md](docs/dim_batch_query_columns.md) |

## Running Queries

Create `.env` from `.env.example`, fill in the source and destination database values, and place private PEM files inside `DB_Config/`.

Run all query files:

```bash
python3 main.py
```

Run one query by target table name:

```bash
python3 main.py --query dim_batch
```

Run with a custom source fetch chunk size:

```bash
python3 main.py --chunk-size 10000
```

By default, each query file in `queries/` writes to a destination table with the same name as the file stem. For example, `queries/dim_batch.sql` writes to `dim_batch`.

Large result sets are streamed from the source database in chunks, then written to the destination table chunk by chunk. Database connections and SSH tunnels are opened through context managers and closed after each operation completes.

## Documentation Standard

Each documented query should explain:

- Output columns
- Source table and source column
- Transform or business logic
- Reason for including the column
- Query-level nullability
- Target DWH table and column
- Whether the source is already a DWH table or production source table

## Notes

The current `dim_batch` query reads from the `quest_rearch_production` source schema and is documented as an input for the DWH table `dim_batch`.
