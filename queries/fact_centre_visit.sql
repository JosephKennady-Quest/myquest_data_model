-- @incremental source_table=quest_rearch_production.mqops_centre_visits id_col=id updated_at_col=updated_at dest_id_col=centre_visit_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : fact_centre_visit
-- Grain    : one row per centre visit (fan-out risk via centre_mqops_centre_visit
--            and mqops_centre_visit_user — multiple centres or related users per visit)
-- Mode     : incremental
-- Source   : quest_rearch_production.mqops_centre_visits,
--            quest_rearch_production.users, quest_rearch_production.centre_types,
--            quest_rearch_production.states, quest_rearch_production.districts,
--            quest_rearch_production.centre_mqops_centre_visit,
--            quest_rearch_production.centres,
--            quest_rearch_production.mqops_centre_visit_user
-- Docs     : docs/fact_centre_visit.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    mcv.id AS centre_visit_id,
    mcv.user_id,
    u.name AS user_name,
    mcv.centre_type_id,
    ct.name AS centre_type_name,
    mcv.state_id,
    s.name AS state_name,
    mcv.district_id,
    d.name AS district_name,
    c.id AS centre_id,
    c.name AS centre_name,
    u2.id AS related_user_id,
    u2.name AS related_user_name,
    mcv.start_date,
    mcv.end_date,
    mcv.visit_purpose,
    mcv.infrastructure,
    mcv.infrastructure_issues,
    mcv.good_practice,
    mcv.publicity_material,
    mcv.placement_issue,
    mcv.quest_content,
    mcv.immediate_action,
    mcv.student_data,
    mcv.meet_authority,
    mcv.trainer_issues,
    mcv.mobilization_issues,
    mcv.digital_lesson,
    mcv.attendance_issues,
    mcv.feedback,
    mcv.rating,
    mcv.created_at,
    mcv.updated_at
FROM quest_rearch_production.mqops_centre_visits AS mcv
LEFT JOIN quest_rearch_production.users AS u
    ON u.id = mcv.user_id
LEFT JOIN quest_rearch_production.centre_types AS ct
    ON ct.id = mcv.centre_type_id
LEFT JOIN quest_rearch_production.states AS s
    ON s.id = mcv.state_id
LEFT JOIN quest_rearch_production.districts AS d
    ON d.id = mcv.district_id
LEFT JOIN quest_rearch_production.centre_mqops_centre_visit AS mcvc
    ON mcvc.mqops_centre_visit_id = mcv.id
LEFT JOIN quest_rearch_production.centres AS c
    ON c.id = mcvc.centre_id
LEFT JOIN quest_rearch_production.mqops_centre_visit_user AS mcvu
    ON mcvu.mqops_centre_visit_id = mcv.id
LEFT JOIN quest_rearch_production.users AS u2
    ON u2.id = mcvu.user_id
