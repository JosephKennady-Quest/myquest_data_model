SELECT a.*,
batch_trade.trade_id

FROM (SELECT
    b.id AS batch_id,
    b.name AS batch_name,
    c.id AS centre_id,
    bp.phase_id AS phase_id,

    /* 
       Project Mapping Logic:
       ------------------------------------------------------------
       1. If batch has phase_id:
            batch -> batch_phase -> phase_project -> project
          This is the primary and correct mapping.

       2. If batch does NOT have phase_id:
            batch -> centre_project -> project
          This is fallback mapping only.

       Why this is needed:
       ------------------------------------------------------------
       A centre can have multiple projects.
       If centre_project is always joined, batches having phase_id
       get incorrectly mapped to extra projects, causing duplicates.

       To avoid incorrect mappings:
       - Use phase-based project when phase exists
       - Use centre_project only when phase_id IS NULL
    */

    COALESCE(pr_phase.id, pr_centre.id) AS project_id,
--     COALESCE(pr_phase.name, pr_centre.name) AS project_name,

    b.start_date AS start_date,
    b.end_date AS end_date,
    b.type AS batch_type,

    CASE 
        WHEN bnp.batch_id IS NULL THEN 1 
        ELSE 0 
    END AS is_ple,

    b.status

FROM quest_rearch_production.batches b

/* Batch -> Phase Mapping */
LEFT JOIN quest_rearch_production.batch_phase bp 
    ON bp.batch_id = b.id

/* Phase -> Project Mapping */
LEFT JOIN quest_rearch_production.phase_project pp
    ON pp.phase_id = bp.phase_id

LEFT JOIN quest_rearch_production.projects pr_phase
    ON pr_phase.id = pp.project_id
   AND pr_phase.status = 1
   AND pr_phase.deleted_at IS NULL

/* 
   Fallback Centre -> Project Mapping
   Applied ONLY when phase_id is NULL
*/
LEFT JOIN quest_rearch_production.centre_project cp
    ON cp.centre_id = b.centre_id
   AND bp.phase_id IS NULL

LEFT JOIN quest_rearch_production.projects pr_centre
    ON pr_centre.id = cp.project_id
   AND pr_centre.status = 1
   AND pr_centre.deleted_at IS NULL

/* PLE / Non-PLE Mapping */
LEFT JOIN quest_rearch_production.batches_non_ple bnp 
    ON bnp.batch_id = b.id

/* Active Centres Only */
INNER JOIN quest_rearch_production.centres c
    ON c.id = b.centre_id
   AND c.status = 1
   AND c.deleted_at IS NULL

WHERE c.id = '54df26ad-0b01-4bed-8470-27d5ae3a63e0'
  AND b.status != 4
  AND b.deleted_at IS NULL

GROUP BY
    b.id,
    b.name,
    c.id,
    bp.phase_id,
    pr_phase.id,
    pr_phase.name,
    pr_centre.id,
    pr_centre.name,
    b.start_date,
    b.end_date,
    b.type,
    bnp.batch_id,
    b.status

ORDER BY b.id) AS a
LEFT JOIN (SELECT
	sd.batch_id,
	sd.trade_id
FROM
	quest_rearch_production.student_details sd
WHERE
	sd.batch_id IS NOT NULL
	AND sd.trade_id IS NOT NULL
GROUP BY
	sd.batch_id,
	sd.trade_id) AS batch_trade ON batch_trade.batch_id = a.batch_id