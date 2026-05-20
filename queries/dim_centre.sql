-- @incremental source_table=quest_rearch_production.centres id_col=id updated_at_col=updated_at dest_id_col=centre_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : dim_centre
-- Grain    : one row per centre (trade_ids aggregated as JSON array)
-- Mode     : incremental
-- Source   : quest_rearch_production.centres, quest_rearch_production.centre_types, quest_rearch_production.centre_trade
-- Docs     : docs/dim_centre.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    c.id AS centre_id,
    c.name AS centre_name,
    c.organisation_id,
    ct.name AS centre_type,
    c.state_id,
    c.district_id,
    JSON_ARRAYAGG(ct2.trade_id) AS trade_ids,
    c.active,
    c.updated_at
FROM quest_rearch_production.centres c
JOIN quest_rearch_production.centre_types ct 
    ON ct.id = c.centre_type_id
LEFT JOIN quest_rearch_production.centre_trade ct2 
    ON ct2.centre_id = c.id
GROUP BY
    c.id,
    c.name,
    c.organisation_id,
    ct.name,
    c.state_id,
    c.district_id,
    c.active;