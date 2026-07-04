-- @incremental source_table=quest_rearch_production.ple_assessment_responses id_col=id updated_at_col=updated_at dest_id_col=response_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : fact_ple_response
-- Grain    : one row per PLE assessment response (response_id)
-- Mode     : incremental
-- Source   : quest_rearch_production.ple_assessment_responses, quest_rearch_production.ple_assessments
-- Docs     : docs/fact_ple_response.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
	par.id AS response_id,
	par.user_id,
	--     pa.title AS assessment_title,
	SUBSTRING_INDEX(pa.title, ' - ', 1) AS assessment_type,
	SUBSTRING_INDEX(pa.title, ' - ', -1) AS assessment_careerpath,
	par.assessment_id,
	par.final_score AS score,
	CASE
		WHEN par.is_complete = 1 THEN par.updated_at
		ELSE NULL
	END AS completed_at,
	par.updated_at
FROM
	quest_rearch_production.ple_assessment_responses par
JOIN quest_rearch_production.ple_assessments pa 
    ON
	pa.id = par.assessment_id
WHERE
		1=1
	-- AND par.user_id IN ('0002b451-65cc-44c8-886e-b5546ec553ec');