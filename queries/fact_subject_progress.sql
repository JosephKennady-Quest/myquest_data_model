-- @dest_only
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : fact_subject_progress
-- Grain    : One row per learner-subject combination
-- Mode     : full (dest_only)
-- Source   : quest_analytics.main_learning_activity_myquest_ael
-- Docs     : docs/fact_subject_progress.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
	m.user_id,
	m.centre_id,
	m.batch_id,
	m.subject_id,
	m.subj_total_completed,
	m.subj_total_allocated,
	(m.subj_total_completed / m.subj_total_allocated)* 100 AS progress_pct
FROM
	quest_analytics.main_learning_activity_myquest_ael m
GROUP BY 
	m.user_id,
	m.subject_id