# dim_centre Query Documentation

Source query: `queries/dim_centre.sql`

This query produces one record per centre, combining the centre's core attributes with its type and a JSON array of all associated trade IDs. It is intended to populate the DWH dimension `dim_centre`, providing a denormalised view of each centre's identity, location references, and trade portfolio for use as a conformed dimension across fact tables.

## Query Grain

One row per centre (`centre_id`). The `GROUP BY` on `c.id` and the `JSON_ARRAYAGG` for trade IDs collapse the one-to-many relationship between centres and trades, so there is no fan-out risk. Each centre appears exactly once regardless of how many trades it is associated with.

## Incremental Configuration

| Setting | Value | Reason |
| --- | --- | --- |
| Source table | `quest_rearch_production.centres` | Centre identity and `updated_at` are driven from the centre record. |
| Source ID column (`id_col`) | `id` | Source primary key used by the pipeline to identify changed records. |
| Destination ID column (`dest_id_col`) | `centre_id` | Output column used by the pipeline to delete and reload changed centre rows. |
| Updated-at column | `updated_at` | Used by the pipeline to detect changed centres for incremental refresh. |

## Global Filters

No global filters.

## Output Columns

| Output column | Source table | Source column | Transform / logic | Reason for inclusion | Nullable in query |
| --- | --- | --- | --- | --- | --- |
| `centre_id` | `quest_rearch_production.centres` alias `c` | `id` | Direct select: `c.id AS centre_id` | Primary centre identifier and natural source key for the dimension. | No |
| `centre_name` | `quest_rearch_production.centres` alias `c` | `name` | Direct select: `c.name AS centre_name` | Human-readable centre name for reporting and filtering. | Depends on source schema |
| `organisation_id` | `quest_rearch_production.centres` alias `c` | `organisation_id` | Direct select: `c.organisation_id` | Links the centre to its parent organisation for org-level aggregation. | Depends on source schema |
| `centre_type` | `quest_rearch_production.centre_types` alias `ct` | `name` | Direct lookup via INNER JOIN on `c.centre_type_id`: `ct.name AS centre_type` | Provides the readable centre type classification. | No — `centre_types` is INNER joined, so centres without a matching type are excluded. |
| `state_id` | `quest_rearch_production.centres` alias `c` | `state_id` | Direct select: `c.state_id` | Geography dimension link for state-level reporting. | Depends on source schema |
| `district_id` | `quest_rearch_production.centres` alias `c` | `district_id` | Direct select: `c.district_id` | Geography dimension link for district-level reporting. | Depends on source schema |
| `trade_ids` | `quest_rearch_production.centre_trade` alias `ct2` | `trade_id` | `JSON_ARRAYAGG(ct2.trade_id)` over LEFT joined rows | Aggregates all trades associated with the centre into a JSON array. Avoids fan-out. Returns `NULL` or `[null]` if no trades exist. | Yes — `centre_trade` is LEFT joined. |
| `active` | `quest_rearch_production.centres` alias `c` | `active` | Direct select: `c.active` | Indicates whether the centre is currently active; used for downstream filtering. | Depends on source schema |
| `updated_at` | `quest_rearch_production.centres` alias `c` | `updated_at` | Direct select: `c.updated_at` | Supports auditability and incremental refresh tracking. | Depends on source schema |

## Entity Relationship Diagram

```mermaid
erDiagram
    centres {
        string id PK
        string name
        string organisation_id
        string centre_type_id FK
        string state_id
        string district_id
        int active
        datetime updated_at
    }
    centre_types {
        string id PK
        string name
    }
    centre_trade {
        string centre_id FK
        string trade_id
    }
    centres ||--|| centre_types : "INNER JOIN on centre_type_id"
    centres ||--o{ centre_trade : "LEFT JOIN on centre_id"
```

## Join and Cardinality Notes

| Join | Join type | Expected effect |
| --- | --- | --- |
| `centres` to `centre_types` | `INNER JOIN` | Excludes centres that have no matching centre type. Each centre maps to exactly one type. |
| `centres` to `centre_trade` | `LEFT JOIN` | Preserves centres with no trade mapping. Multiple trade rows per centre are collapsed into a JSON array by `GROUP BY` + `JSON_ARRAYAGG`. |

## DWH Interpretation

| Item | Value |
| --- | --- |
| Intended DWH table | `dim_centre` |
| DWH grain risk | No fan-out risk. The `GROUP BY` on `c.id` ensures one row per centre. `trade_ids` is stored as a JSON array rather than expanding rows. |
| Production source schema | `quest_rearch_production` |
| DWH source status | The query reads from production source tables, not DWH tables. |
| Output DWH columns | `centre_id`, `centre_name`, `organisation_id`, `centre_type`, `state_id`, `district_id`, `trade_ids`, `active`, `updated_at` |
