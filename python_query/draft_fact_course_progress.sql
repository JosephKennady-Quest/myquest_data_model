-- -- @incremental source_table=quest_rearch_production.course_progress id_col=id updated_at_col=updated_at

-- -- @incremental source_table=quest_rearch_production.subject_progress id_col=id updated_at_col=updated_at

-- SELECT
--     la.user_id,
--     s.id AS subject_id,
--     co.id AS course_id,
--     c.id AS centre_id,
--     sd.batch_id,

--     MIN(la.created_at) AS started_at,
--     MAX(la.created_at) AS last_active_at,

--     pu.phase_id,

--     COUNT(DISTINCT la.id) AS completed_lessons,

--     lesson_counts.total_lessons,

--     ROUND(
--         (COUNT(DISTINCT la.id) * 100.0) / lesson_counts.total_lessons,
--         2
--     ) AS progress_pct,

--     CASE
--         WHEN (COUNT(DISTINCT la.id) * 1.0 / lesson_counts.total_lessons) >= 1
--         THEN 1
--         ELSE 0
--     END AS completed_flag

-- FROM quest_rearch_production.learning_activities la

-- JOIN quest_rearch_production.lessons l 
--     ON l.id = la.lesson_id 

-- JOIN quest_rearch_production.subjects s 
--     ON s.id = l.subject_id 

-- JOIN quest_rearch_production.users u 
--     ON u.id = la.user_id 

-- JOIN quest_rearch_production.courses co 
--     ON co.subject_id = s.id

-- JOIN quest_rearch_production.centres c 
--     ON c.id = u.centre_id 

-- JOIN quest_rearch_production.student_details sd 
--     ON sd.user_id = u.id

-- JOIN quest_rearch_production.phase_users pu 
--     ON pu.user_id = u.id

-- LEFT JOIN (
--     SELECT
--         s.id AS subject_id,
--         COUNT(DISTINCT l.id) AS total_lessons 
--     FROM quest_rearch_production.subjects s
--     JOIN quest_rearch_production.lessons l 
--         ON l.subject_id = s.id
--     JOIN quest_rearch_production.courses co 
--         ON co.subject_id = s.id
--     WHERE
--         l.status = 1
--         AND l.deleted_at IS NULL
--     GROUP BY s.id, co.id
-- ) AS lesson_counts 
--     ON lesson_counts.subject_id = s.id

-- WHERE
--     la.completed = 1
--     AND u.type IN (3, 4)
--     AND u.status = 1
--     AND u.deleted_at IS NULL
--     AND s.status = 1
--     AND s.deleted_at IS NULL
--     AND l.status = 1
--     AND l.deleted_at IS NULL
--     AND u.id IN ('20b04387-0191-4aba-80e7-0314eb4f709c')

-- GROUP BY
--     la.user_id,
--     s.id,
--     co.id,
--     c.id,
--     sd.batch_id,
--     pu.phase_id,
--     lesson_counts.total_lessons;