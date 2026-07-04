-- @dest_only

SELECT
    a.user_id AS tlo_users_id,
--     a.created_at,

--     a.user_type,

    CASE
        WHEN a.user_type = 1 THEN 'Admin'
        WHEN a.user_type = 2 AND b.is_master_trainer = 1 THEN 'Master Trainer'
        WHEN a.user_type = 2 THEN 'Facilitator'
        WHEN a.user_type = 3 THEN 'Learner'
        WHEN a.user_type = 4 THEN 'Alumni'
        ELSE 'Missing Data'
    END AS user_type_e,

--     CASE
--         WHEN b.ple_enabled = 1 THEN 'PLE Centre'
--         ELSE 'Non-PLE Centre'
--     END AS ple_enabled_e,

--     CASE
--         WHEN a.is_ple = 1 THEN 'PLE'
--         ELSE 'Non-PLE'
--     END AS is_ple_e,

    a.is_ple,

    a.project_combos,

--     a.total_allocated AS a_overa_less_asses_c,
--     a.total_assessments_allocated AS a_overa_assess_c,
--     a.total_lessons_allocated AS a_overa_lesson_c,

--     a.total_completed AS c_overa_less_asses_c,
--     a.total_assessments_completed AS c_overa_asse_c,
--     a.total_lessons_completed AS c_overa_less_c,

--     ROUND(a.completion_pct) AS rounded_completion,

    b.username AS user_name,
    b.gender,
    b.centre_name,
    b.org_name,
    b.state_name,
    b.district_name,
    b.trade,
    b.batch_name,
    b.batch_status,
    b.centre_type,
    b.platform,
    b.ple_enabled,
    b.first_login,
    b.is_master_trainer,
    a.subject_combos,
    

    -- Subject columns
    s.subject_id,
    s.subject_name,
    s.year_category,
    s.avg_score,
    s.avg_rating,
    s.allocated_lessons,
    s.completed_lessons,
    s.allocated_assessments,
    s.completed_assessments,
    s.allocated_lessons_and_assessments,
    s.completed_lessons_and_assessments

FROM quest_analytics.production_users_one_record a

JOIN quest_analytics.user_addon b
    ON b.user_id = a.user_id

CROSS JOIN JSON_TABLE(
    a.subject_combos,
    '$[*]'
    COLUMNS (
        subject_id VARCHAR(100) PATH '$.subject_id',
        subject_name VARCHAR(255) PATH '$.subject_name',
        year_category VARCHAR(100) PATH '$.year_category',
        avg_score DECIMAL(10,2) PATH '$.avg_score',
        avg_rating DECIMAL(10,2) PATH '$.avg_rating',
        allocated_lessons INT PATH '$.allocated_lessons',
        completed_lessons INT PATH '$.completed_lessons',
        allocated_assessments INT PATH '$.allocated_assessments',
        completed_assessments INT PATH '$.completed_assessments',
        allocated_lessons_and_assessments INT PATH '$.allocated_lessons_and_assessments',
        completed_lessons_and_assessments INT PATH '$.completed_lessons_and_assessments'
    )
) s

WHERE 1 = 1

AND a.subject_combos IS NOT NULL 

AND JSON_UNQUOTE(
    JSON_EXTRACT(a.project_combos, '$[0].prog_name')
) IN ('MyQuest', 'Quest Experience Lab')