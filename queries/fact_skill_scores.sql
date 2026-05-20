-- @incremental source_table=quest_rearch_production.ple_skill_user id_col=id updated_at_col=updated_at dest_id_col=score_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : fact_skill_scores
-- Grain    : intended one row per skill-user (score_id) — BUG: GROUP BY user only, not skill
-- Mode     : incremental
-- Source   : quest_rearch_production.ple_skill_user, quest_rearch_production.learning_activities
-- Docs     : docs/fact_skill_scores.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
	psu.id AS score_id,
	psu.user_id, 
	psu.skill_id, 
	AVG(la.score) AS score,
	la.created_at AS assessed_at,
	1=1
-- 	assessment_round
FROM
	quest_rearch_production.ple_skill_user psu
LEFT JOIN
	quest_rearch_production.learning_activities la ON la.user_id = psu.user_id
	AND la.completed = 1
WHERE 1=1
AND psu.deleted_at IS NULL
AND la.completed = 1
AND la.user_id IN ('0000ea31-8320-4974-b389-af6a2d725d44')
AND psu.user_id IN ('0000ea31-8320-4974-b389-af6a2d725d44')
GROUP BY psu.user_id

