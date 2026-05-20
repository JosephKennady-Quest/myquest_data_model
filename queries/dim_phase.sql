-- @incremental source_table=quest_rearch_production.phases id_col=id updated_at_col=updated_at dest_id_col=phase_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : dim_phase
-- Grain    : one row per phase (assumes phase_project is one-to-one)
-- Mode     : incremental
-- Source   : quest_rearch_production.phases, quest_rearch_production.phase_project, quest_rearch_production.projects, quest_rearch_production.programs
-- Docs     : docs/dim_phase.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    p.id AS phase_id,
    p.name AS phase_name,
    p3.id AS program_id,
    p2.id AS project_id,
    -- p.cohort_year,
    p.start_date,
    p.end_date,
    CASE 
        WHEN p.end_date <= CURDATE() THEN 2 
        ELSE 1 
    END AS status,
    p.updated_at
FROM quest_rearch_production.phases p
JOIN quest_rearch_production.phase_project pp 
    ON pp.phase_id = p.id
JOIN quest_rearch_production.projects p2 
    ON p2.id = pp.project_id
JOIN quest_rearch_production.programs p3 
    ON p3.id = p2.program_id
WHERE p.deleted_at IS NULL
    AND p2.deleted_at IS NULL
    AND p3.deleted_at IS NULL;