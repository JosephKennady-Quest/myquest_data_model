-- @incremental source_table=quest_rearch_production.users id_col=id updated_at_col=updated_at dest_id_col=learner_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : dim_placement_learner
-- Grain    : intended one row per learner_id (fan-out risk from centre_project)
-- Mode     : incremental
-- Source   : quest_rearch_production.users, quest_rearch_production.student_details, quest_rearch_production.educational_qualifications, quest_rearch_production.centre_project, quest_rearch_production.projects, quest_rearch_production.programs, quest_rearch_production.placements, quest_rearch_production.placement_status
-- Docs     : docs/dim_placement_learner_query_columns.md
-- ─────────────────────────────────────────────────────────────────────────────

/*
    dim_placement_learner
    ---------------------------------------------------------------------------
    Purpose:
        Builds the learner dimension from production user, student profile,
        centre-project-program, education, and placement data.

    Grain:
        Intended output grain is one row per learner_id. However, the joins to
        centre_project/projects/programs can return more than one row per learner
        if the learner's centre is mapped to multiple projects/programs. If the
        DWH table must be strictly one row per learner, add business rules to
        select one project/program per centre or aggregate before loading.

    Incremental behavior:
        The @incremental header tells the Python pipeline to inspect
        quest_rearch_production.users.updated_at and refresh rows where the
        output learner_id has changed since the last successful run.

    Key mapping logic:
        1. Learner identity and PLE flag come from users.
        2. Student profile attributes, including trade and family income band,
           come from student_details.
        3. First program is currently derived from the learner centre's linked
           project/program path:
              users.centre_id -> centre_project -> projects -> programs
        4. Employment status at enrolment is selected from the most recently
           updated non-deleted placement record for the configured enrolment
           placement_type_id.
*/

SELECT
    u.id AS learner_id,
    eq.name AS educational_qualification,
    u.is_ple,
    u.gender,
    c.name AS centre_name,
    ct.name AS centre_type,
    u.type AS learner_type,
    s.name AS centre_state,
    sd.trade_id,
    pd.employment_status_at_enrolment,
    sd.guardian_income AS family_income_band,
    p.name AS first_program,
    u.created_at AS first_enrolled_at,
    u.updated_at
FROM quest_rearch_production.users AS u
JOIN quest_rearch_production.student_details AS sd
    ON sd.user_id = u.id
JOIN quest_rearch_production.centres AS c
    ON c.id = u.centre_id
JOIN quest_rearch_production.centre_project AS cp
    ON cp.centre_id = c.id
JOIN quest_rearch_production.states AS s
    ON s.id = c.state_id
JOIN quest_rearch_production.centre_types AS ct
    ON ct.id = c.centre_type_id
JOIN quest_rearch_production.projects AS p2
    ON p2.id = cp.project_id
JOIN quest_rearch_production.programs AS p
    ON p.id = p2.program_id
LEFT JOIN quest_rearch_production.educational_qualifications AS eq
    ON eq.id = sd.educational_qualification_id
LEFT JOIN (
    /*
        Pick one enrolment placement status per learner.
        ROW_NUMBER ranks placement records newest first by pl.updated_at, and
        the outer WHERE rn = 1 keeps only the latest qualifying placement row.
    */
    SELECT
        user_id,
        employment_status_at_enrolment
    FROM (
        SELECT
            pl.user_id,
            ps.name AS employment_status_at_enrolment,
            ROW_NUMBER() OVER (
                PARTITION BY pl.user_id
                ORDER BY pl.updated_at DESC
            ) AS rn
        FROM quest_rearch_production.placements AS pl
        LEFT JOIN quest_rearch_production.placement_status AS ps
            ON ps.id = pl.placement_status_id
        WHERE pl.placement_type_id IN (
            '1627ed64-074f-4f92-9b6c-c7fb6aa0bc2c'
        )
        AND pl.deleted_at IS NULL
        AND pl.user_id IS NOT NULL
    ) AS ranked_placements
    WHERE rn = 1
) AS pd
    ON pd.user_id = u.id
WHERE u.status = 1
    AND u.deleted_at IS NULL;
