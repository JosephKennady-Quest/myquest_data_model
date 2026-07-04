-- @incremental source_table=quest_rearch_production.centres id_col=id updated_at_col=updated_at dest_id_col=centre_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : dim_centre
-- Grain    : one row per centre (trade_ids aggregated as JSON array)
-- Mode     : incremental
-- Source   : quest_rearch_production.centres, quest_rearch_production.centre_types, quest_rearch_production.centre_trade, quest_rearch_production.centre_project, quest_rearch_production.projects, quest_rearch_production.programs, quest_rearch_production.phase_project, quest_rearch_production.phases
-- Docs     : docs/dim_centre.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    c.id AS centre_id,
    c.name AS centre_name,
    c.organisation_id,
    ct.name AS centre_type,
    s.name AS state_name,
    d.name AS district_name,
    JSON_ARRAYAGG(ct2.trade_id) AS trade_ids,
    pagg.projects,
    c.active,
    c.updated_at
FROM quest_rearch_production.centres c
JOIN quest_rearch_production.centre_types ct 
    ON ct.id = c.centre_type_id
LEFT JOIN quest_rearch_production.centre_trade ct2 
    ON ct2.centre_id = c.id
LEFT JOIN quest_rearch_production.states s 
    ON s.id = c.state_id
LEFT JOIN quest_rearch_production.districts d
    ON d.id = c.district_id
LEFT JOIN (
    SELECT
        base.centre_id,
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'project_id',   base.project_id,
                'project_name', base.project_name,
                'program_id',   base.program_id,
                'program_name', base.program_name,
                'phase_id',     base.phase_id,
                'phase_name',   base.phase_name
            )
        ) AS projects
    FROM (
        SELECT DISTINCT
            cp.centre_id,
            p.id   AS project_id,
            p.name AS project_name,
            pr.id  AS program_id,
            pr.name AS program_name,
            ph.id  AS phase_id,
            ph.name AS phase_name
        FROM quest_rearch_production.centre_project cp
        JOIN quest_rearch_production.projects p  ON p.id  = cp.project_id
        JOIN quest_rearch_production.programs pr ON pr.id = p.program_id
        LEFT JOIN quest_rearch_production.phase_project pp ON pp.project_id = p.id
        LEFT JOIN quest_rearch_production.phases ph ON ph.id = pp.phase_id
    ) base
    GROUP BY base.centre_id
) pagg ON pagg.centre_id = c.id
WHERE 1=1
AND c.deleted_at IS NULL
AND c.status = 1
GROUP BY
    c.id,
    c.name,
    c.organisation_id,
    ct.name,
    c.state_id,
    c.district_id,
    pagg.projects,
    c.active;

