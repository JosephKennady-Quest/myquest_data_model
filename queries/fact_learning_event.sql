-- @incremental source_table=quest_rearch_production.learning_activities id_col=id updated_at_col=updated_at dest_id_col=learning_activity_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : fact_learning_event
-- Grain    : intended one row per learning_activity_id (BUG: SUM without GROUP BY collapses to one row)
-- Mode     : incremental
-- Source   : quest_rearch_production.learning_activities, quest_rearch_production.lessons, quest_rearch_production.subjects, quest_rearch_production.courses, quest_rearch_production.users
-- Docs     : docs/fact_learning_event.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT la.id AS learning_activity_id,
la.user_id,
l.subject_id AS subject_id,
c.id AS course_id,
l.id AS lesson_id,
u.centre_id AS centre_id,
-- date_id,
SUM(la.duration) AS total_duration_secs,
-- events_count,
-- mode (online/offline)
la.updated_at AS updated_at

FROM quest_rearch_production.learning_activities la 
JOIN quest_rearch_production.lessons l ON l.id = la.lesson_id 
JOIN quest_rearch_production.subjects s ON s.id = l.subject_id 
JOIN quest_rearch_production.courses c ON c.subject_id = s.id
JOIN quest_rearch_production.users u ON u.id = la.user_id

WHERE u.deleted_at IS NULL
AND u.status = 1
AND la.completed = 1
AND s.status = 1
AND l.status = 1
AND l.deleted_at IS NULL 
AND s.deleted_at IS NULL
AND la.created_at >= '2026-05-01'
AND la.user_id IN ('0002b451-65cc-44c8-886e-b5546ec553ec')