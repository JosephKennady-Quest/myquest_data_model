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
	ps.name AS skill_name,
	AVG(la.score) AS score,
	st.name AS state_name,
	u.gender AS gender,
	c.name AS centre_name,
	ct.name AS centre_type,
	la.created_at AS assessed_at,
	psu.updated_at AS updated_at
-- 	assessment_round
FROM
	quest_rearch_production.ple_skill_user psu
LEFT JOIN
	quest_rearch_production.learning_activities la ON la.user_id = psu.user_id
	AND la.completed = 1
LEFT JOIN quest_rearch_production.users u ON u.id = psu.user_id
	AND u.deleted_at IS NULL
	AND u.status = 1
LEFT JOIN quest_rearch_production.states st ON st.id = u.state_id
LEFT JOIN quest_rearch_production.centres c ON c.id = u.centre_id
	AND c.deleted_at IS NULL
	AND c.status = 1
LEFT JOIN quest_rearch_production.centre_types ct ON ct.id = c.centre_type_id
LEFT JOIN quest_rearch_production.ple_skills ps ON ps.id = psu.skill_id
	AND ps.deleted_at IS NULL
	AND ps.status = 1
WHERE 1=1
AND psu.deleted_at IS NULL
AND la.completed = 1
AND la.user_id IN ('0000ea31-8320-4974-b389-af6a2d725d44')
AND psu.user_id IN ('0000ea31-8320-4974-b389-af6a2d725d44')
GROUP BY psu.user_id

