-- @incremental source_table=quest_rearch_production.users id_col=id updated_at_col=updated_at dest_id_col=educator_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : dim_educator
-- Grain    : intended one row per educator (fan-out risk from centre_project)
-- Mode     : incremental
-- Source   : quest_rearch_production.users, quest_rearch_production.facilitator_details, quest_rearch_production.centre_project, quest_rearch_production.projects, quest_rearch_production.programs
-- Docs     : docs/dim_educator.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    u.id AS educator_id,
    fd.designation AS designation,
    fd.experience AS experience_yrs,
    fd.qualification AS qualification,
    -- fd.certification_level,
    u.is_master_trainer AS mastercoach_flag,
    u.centre_id,
    p.id AS program_id,
    u.updated_at
FROM quest_rearch_production.users AS u
JOIN quest_rearch_production.facilitator_details AS fd
    ON fd.user_id = u.id
JOIN quest_rearch_production.centre_project AS cp
    ON cp.centre_id = u.centre_id
JOIN quest_rearch_production.projects AS p2
    ON p2.id = cp.project_id
JOIN quest_rearch_production.programs AS p
    ON p.id = p2.program_id
WHERE 1=1
	AND u.status = 1
    AND u.deleted_at IS NULL
    AND u.type = 2