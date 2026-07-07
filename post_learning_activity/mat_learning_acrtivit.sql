SELECT
	flp.activity_id,
	flp.user_id,
	flp.subject_id,
	flp.lesson_id,
	flp.course_id,
	flp.lesson_name,
	flp.lesson_order,
	flp.is_assessment,
	flp.score,
	flp.rating,
	flp.duration,
	flp.created_at,
	flp.completed,
	flp.completed_at,
	dlp.educational_qualification,
	dlp.gender,
	dlp.centre_name,
	dlp.centre_type,
	dlp.learner_type,
	dlp.centre_state,
	ds.subject_name
FROM
	fact_lesson_progress flp
LEFT JOIN dim_placement_learner dlp ON
	dlp.learner_id = flp.user_id
LEFT JOIN dim_subject ds ON 
	ds.subject_id = flp.subject_id 

