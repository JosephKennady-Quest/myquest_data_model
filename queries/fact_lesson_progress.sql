-- @dest_only
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : fact_lesson_progress
-- Grain    : One row per learner-lesson combination
-- Mode     : full (dest_only)
-- Source   : quest_analytics.main_learning_activity_myquest_ael_lesson
-- Docs     : docs/fact_lesson_progress.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
	m.user_id,
	m.centre_id,
	m.batch_id,
	m.subject_id,
	m.lesson_id,
	m.completed,
	m.duration AS time_spent_secs
FROM
	quest_analytics.main_learning_activity_myquest_ael_lesson m
GROUP BY 
	m.user_id,
	m.subject_id,
	m.lesson_id 