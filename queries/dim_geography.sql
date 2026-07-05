-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : dim_geography
-- Grain    : one row per centre (centre-state-district lookup)
-- Mode     : full (no @incremental header — reruns as a full replace every time)
-- Source   : quest_rearch_production.centres, quest_rearch_production.states, quest_rearch_production.districts
-- Docs     : docs/dim_geography.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    c.id AS centre_id,
    c.name AS centre,
    -- d.id AS district_id,
    d.name AS district,
    -- s.id AS state_id,
    s.name AS state
FROM quest_rearch_production.centres c
JOIN quest_rearch_production.states s ON s.id = c.state_id 
JOIN quest_rearch_production.districts d ON d.id = c.district_id
WHERE c.status = 1
AND c.deleted_at IS NULL;