-- @incremental source_table=quest_rearch_production.mqops_session_trackers id_col=id updated_at_col=created_at dest_id_col=id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : fact_session
-- Grain    : one row per session tracker record
-- Mode     : incremental
-- Source   : quest_rearch_production.mqops_session_trackers,
--            quest_rearch_production.users, quest_rearch_production.session_types,
--            quest_rearch_production.states, quest_rearch_production.districts,
--            quest_rearch_production.centre_types, quest_rearch_production.mqops_activity_mediums,
--            quest_rearch_production.centre_mqops_session_tracker,
--            quest_rearch_production.centres, quest_rearch_production.mqops_session_modules,
--            quest_rearch_production.projects, quest_rearch_production.phases
-- Docs     : docs/fact_session.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
	`sess`.`id` AS `id`,
	`u`.`name` AS `user_name`,
	`sess`.`created_at` AS `created_at`,
	`st`.`name` AS `session_type_name`,
	`s`.`name` AS `state_name`,
	`d`.`name` AS `district_name`,
	`ct`.`name` AS `centre_type_name`,

	`mm`.`name` AS `session_medium`,
	`pre`.`centres` AS `centres`,
	`modagg`.`session_modules` AS `session_modules`,
	`sess`.`start_date` AS `start_date`,
	`sess`.`end_date` AS `end_date`,
	`sess`.`duration` AS `duration`,
	`sess`.`ext_person_name` AS `ext_person_name`,
	`sess`.`company_name` AS `company_name`,
	`sess`.`guest_type_id` AS `guest_type_id`,
	`sess`.`volunteer_count` AS `volunteer_count`,
	`sess`.`session_details` AS `session_details`,
	`sess`.`participant_count` AS `participant_count`,
	`sess`.`male_participant_count` AS `male_participant_count`,
	`sess`.`female_participant_count` AS `female_participant_count`,
	`sess`.`other_participant_count` AS `other_participant_count`,
	`sess`.`topics_covered` AS `topics_covered`,
	`sess`.`es_trainer_present` AS `es_trainer_present`,
	`sess`.`career_club_role` AS `career_club_role`,
	`sess`.`mobile_access_count` AS `mobile_access_count`,
	`sess`.`insight_from_learners` AS `insight_from_learners`,
	`sess`.`need_support_explore` AS `need_support_explore`,
	`sess`.`support_for_app` AS `support_for_app`,
	`sess`.`organised_by_institution` AS `organised_by_institution`,
	`sess`.`any_practice` AS `any_practice`,
	`sess`.`key_highlights` AS `key_highlights`,
	`sess`.`have_resources` AS `have_resources`,
	`sess`.`others_institution` AS `others_institution`,
	`sess`.`others_support` AS `others_support`,
	`sess`.`others_support_app` AS `others_support_app`,
	`sess`.`leaders_role` AS `leaders_role`,
	`sess`.`district_id` AS `district_id`,
	`sess`.`elaborate_any_practice` AS `elaborate_any_practice`,
	`sess`.`insight_explain` AS `insight_explain`,
	`sess`.`elaborate_learner_hub` AS `elaborate_learner_hub`,
	`sess`.`learner_journey_phase` AS `learner_journey_phase`,
	`sess`.`career_sectors_discussed` AS `career_sectors_discussed`,
	`sess`.`identify_career_path` AS `identify_career_path`,
	`sess`.`name_career_pathways` AS `name_career_pathways`,
	`sess`.`challenges_career_pathways` AS `challenges_career_pathways`,
	`sess`.`pilot_activity` AS `pilot_activity`,
	`sess`.`feedback_gathered` AS `feedback_gathered`,
	`sess`.`learner_clarity` AS `learner_clarity`,
	`sess`.`feedback_details` AS `feedback_details`,
	`sess`.`factors_help_learner` AS `factors_help_learner`,
	`sess`.`others_learner_help` AS `others_learner_help`,
	`sess`.`learners_have_questions` AS `learners_have_questions`,
	`sess`.`learner_questions` AS `learner_questions`,
	`sess`.`learner_motivation_per` AS `learner_motivation_per`,
	`sess`.`learners_interested_per` AS `learners_interested_per`,
	`sess`.`actionable_takeways` AS `actionable_takeways`,
	`sess`.`who_facilitated_session` AS `who_facilitated_session`,
	`sess`.`key_topics_covered` AS `key_topics_covered`,
	`sess`.`did_learner_engage` AS `did_learner_engage`,
	`sess`.`parents_family_count` AS `parents_family_count`,
	`sess`.`green_pilot_activity` AS `green_pilot_activity`,
	`sess`.`green_skills_conducted` AS `green_skills_conducted`,
	`sess`.`green_skills_addressed` AS `green_skills_addressed`,
	`sess`.`increased_understanding` AS `increased_understanding`,
	`sess`.`follow_up_oppurtunity` AS `follow_up_oppurtunity`,
	`sess`.`learner_queries` AS `learner_queries`,
	`sess`.`express_interest` AS `express_interest`,
	`sess`.`work_clarity` AS `work_clarity`,
	`sess`.`any_common_concern` AS `any_common_concern`,
	`sess`.`rubric_provided` AS `rubric_provided`,
	`sess`.`confidence_level` AS `confidence_level`,
	`sess`.`primary_purpose` AS `primary_purpose`,
	`sess`.`who_facilitated` AS `who_facilitated`,
	`sess`.`any_technical_challenges` AS `any_technical_challenges`,
	`sess`.`elaborate_challenges` AS `elaborate_challenges`,
	`sess`.`learners_navigate` AS `learners_navigate`,
	`sess`.`not_confident` AS `not_confident`,
	`sess`.`baseline_assessment` AS `baseline_assessment`,
	`sess`.`learners_challenges` AS `learners_challenges`,
	`sess`.`volunteer_session_type` AS `volunteer_session_type`,
	`sess`.`other_volunteer_session` AS `other_volunteer_session`,
	`sess`.`learner_engage_volunteer` AS `learner_engage_volunteer`,
	`sess`.`session_year` AS `session_year`,
	`sess`.`session_module_covered` AS `session_module_covered`,
	`sess`.`percent_active_learners` AS `percent_active_learners`,
	`sess`.`intended_outcome` AS `intended_outcome`,
	`sess`.`facilitator` AS `facilitator`,
	`sess`.`learning_strategies` AS `learning_strategies`,
	`sess`.`innovative_methods` AS `innovative_methods`,
	`sess`.`innovative_yes` AS `innovative_yes`,
	`sess`.`follow_up_actions` AS `follow_up_actions`,
	`sess`.`follow_up_yes` AS `follow_up_yes`,
	`sess`.`assessment_type` AS `assessment_type`,
	`sess`.`challenges` AS `challenges`,
	`sess`.`challenges_yes` AS `challenges_yes`,
	`sess`.`endline_challenges` AS `endline_challenges`,
	`sess`.`feedback_participant` AS `feedback_participant`,
	`sess`.`form_pdf` AS `form_pdf`
FROM
	((((((((((`quest_rearch_production`.`mqops_session_trackers` `sess`
LEFT JOIN `quest_rearch_production`.`users` `u` ON
	((`sess`.`user_id` = `u`.`id`)))
LEFT JOIN (
	-- Aggregate linked centres before joining to keep one row per session tracker.
	SELECT
		`sess`.`id` AS `id`,
		group_concat(DISTINCT `cen`.`name` separator ',') AS `centres`
	FROM
		((`quest_rearch_production`.`mqops_session_trackers` `sess`
	LEFT JOIN `quest_rearch_production`.`centre_mqops_session_tracker` `cm` ON
		((`cm`.`mqops_session_tracker_id` = `sess`.`id`)))
	LEFT JOIN `quest_rearch_production`.`centres` `cen` ON
		((`cm`.`centre_id` = `cen`.`id`)))
	WHERE
		(`sess`.`deleted_at` IS NULL)
	GROUP BY
		`sess`.`id`) AS `pre` ON
	((`sess`.`id` = `pre`.`id`)))
LEFT JOIN (
	-- Resolve comma-separated module IDs into names before joining.
	SELECT
		`sess`.`id` AS `id`,
		group_concat(DISTINCT `m`.`name` separator ', ') AS `session_modules`
	FROM
		(`quest_rearch_production`.`mqops_session_trackers` `sess`
	JOIN `quest_rearch_production`.`mqops_session_modules` `m` ON
		((find_in_set(`m`.`id`,`sess`.`session_module_covered`) > 0)))
	WHERE
		(`sess`.`deleted_at` IS NULL)
	GROUP BY
		`sess`.`id`) `modagg` ON
	((`sess`.`id` = `modagg`.`id`)))
LEFT JOIN `quest_rearch_production`.`session_types` `st` ON
	((`sess`.`session_type_id` = `st`.`id`)))
LEFT JOIN `quest_rearch_production`.`states` `s` ON
	((`s`.`id` = `sess`.`state_id`)))
LEFT JOIN `quest_rearch_production`.`districts` `d` ON
	((`d`.`id` = `sess`.`district_id`)))
LEFT JOIN `quest_rearch_production`.`projects` `pro` ON
	((`pro`.`id` = `sess`.`project_id`)))
LEFT JOIN `quest_rearch_production`.`phases` `ph` ON
	((`ph`.`id` = `sess`.`phase_id`)))
LEFT JOIN `quest_rearch_production`.`mqops_activity_mediums` `mm` ON
	((`sess`.`mqops_activity_medium_id` = `mm`.`id`)))
LEFT JOIN `quest_rearch_production`.`centre_types` `ct` ON
	((`sess`.`centre_type_id` = `ct`.`id`)))
WHERE
	(`sess`.`deleted_at` IS NULL)
