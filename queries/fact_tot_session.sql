-- @incremental source_table=quest_rearch_production.mqops_tot_summary id_col=id updated_at_col=updated_at dest_id_col=tot_summary_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : fact_tot_session
-- Grain    : one row per ToT summary-centre combination (fan-out via
--            mqops_tot_summary_centre — multiple centres per ToT session)
-- Mode     : incremental
-- Source   : quest_rearch_production.mqops_tot_summary,
--            quest_rearch_production.mqops_tot_summary_centre,
--            quest_rearch_production.users, quest_rearch_production.mqops_tot_types,
--            quest_rearch_production.states, quest_rearch_production.centres
-- Docs     : docs/fact_tot_session.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
	mts.id AS tot_summary_id,
	u.name AS user_name,
	s.name AS state_name,
	mts.mode,
	mts.ecosystem_id,
	mtsp.participant_count,
	mtsp.female_participant_count,
	mtsp.male_participant_count,
	mtsp.other_participant_count,
	mtt.name AS tot_name,
	mts.start_date,
	mts.end_date,
	c.name AS centre_name,
	mtsp.stake_holder_name,
	mts.updated_at
FROM quest_rearch_production.mqops_tot_summary AS mts
LEFT JOIN quest_rearch_production.mqops_tot_summary_centre AS mtsp
	ON mts.id = mtsp.tot_summary_id
LEFT JOIN quest_rearch_production.users AS u
	ON u.id = mts.user_id
LEFT JOIN quest_rearch_production.mqops_tot_types AS mtt
	ON mtt.id = mts.tot_id
LEFT JOIN quest_rearch_production.states AS s
	ON mtsp.state_id = s.id
LEFT JOIN quest_rearch_production.centres AS c
	ON c.id = mtsp.centre_id
WHERE
	mts.deleted_at IS NULL
