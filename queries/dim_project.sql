-- @incremental source_table=quest_rearch_production.projects id_col=id updated_at_col=updated_at dest_id_col=project_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : dim_project
-- Grain    : one row per project
-- Mode     : incremental
-- Source   : quest_rearch_production.projects, quest_rearch_production.programs
-- Docs     : docs/dim_project.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    p.id AS project_id,
    p.name AS project_name,
    p2.id AS program_id,
    p2.name AS program_name,
    p.updated_at
FROM quest_rearch_production.projects AS p
JOIN quest_rearch_production.programs AS p2
    ON p2.id = p.program_id
WHERE
    1 = 1
    AND p.status = 1
    AND p2.status = 1
    AND p.deleted_at IS NULL
    AND p2.deleted_at IS NULL
