-- @incremental source_table=quest_rearch_production.subjects id_col=id updated_at_col=updated_at dest_id_col=subject_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : dim_subject
-- Grain    : one row per subject (multi-path fan-out collapsed by GROUP BY + JSON_ARRAYAGG)
-- Mode     : incremental
-- Source   : quest_rearch_production.subjects, quest_rearch_production.subject_trade, quest_rearch_production.phase_subject, quest_rearch_production.centre_subject, quest_rearch_production.centre_project, quest_rearch_production.projects, quest_rearch_production.centre_trade
-- Docs     : docs/dim_subject.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    s.id AS subject_id,
    s.name AS subject_name,
    s.tag AS identity_tag,

    JSON_ARRAYAGG(DISTINCT p.program_id) AS program_ids,
    JSON_ARRAYAGG(DISTINCT st.trade_id) AS trade_ids,
    JSON_ARRAYAGG(DISTINCT p.id) AS project_ids,

    s.active AS active,
	s.updated_at AS updated_at
FROM quest_rearch_production.subjects s

JOIN quest_rearch_production.subject_trade st 
    ON st.subject_id = s.id

JOIN quest_rearch_production.phase_subject ps 
    ON ps.subject_id = s.id

JOIN quest_rearch_production.centre_subject cs 
    ON cs.subject_id = s.id

JOIN quest_rearch_production.centre_project cp 
    ON cp.centre_id = cs.centre_id 

JOIN quest_rearch_production.projects p 
    ON p.id = cp.project_id 

JOIN quest_rearch_production.centre_trade ct 
    ON ct.centre_id = cs.centre_id
    AND st.trade_id = ct.trade_id

GROUP BY
    s.id,
    s.name,
    s.tag,
    s.active;