-- @incremental source_table=quest_rearch_production.subjects id_col=id updated_at_col=updated_at dest_id_col=subject_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : dim_subject
-- Grain    : one row per subject (multi-path fan-out collapsed by GROUP BY + JSON_ARRAYAGG)
-- Mode     : incremental
-- Source   : quest_rearch_production.subjects, quest_rearch_production.subject_trade, quest_rearch_production.phase_subject, quest_rearch_production.centre_subject, quest_rearch_production.centre_project, quest_rearch_production.projects, quest_rearch_production.centre_trade, quest_rearch_production.lessons
-- Docs     : docs/dim_subject.md
-- ─────────────────────────────────────────────────────────────────────────────

-- MySQL does not support DISTINCT inside JSON_ARRAYAGG.
-- Deduplication is done in the inner subquery; the outer query aggregates the unique values.
SELECT
    s.id AS subject_id,
    s.name AS subject_name,
    s.tag AS identity_tag,
    agg.program_ids,
    agg.trade_ids,
    agg.project_ids,
    lagg.lesson_ids,
    s.status AS active,
    s.updated_at AS updated_at
FROM quest_rearch_production.subjects s
JOIN (
    SELECT
        base.subject_id,
        JSON_ARRAYAGG(base.program_id) AS program_ids,
        JSON_ARRAYAGG(base.trade_id)   AS trade_ids,
        JSON_ARRAYAGG(base.project_id) AS project_ids
    FROM (
        SELECT DISTINCT
            cs.subject_id,
            p.program_id,
            st.trade_id,
            p.id AS project_id
        FROM quest_rearch_production.subject_trade st
        JOIN quest_rearch_production.centre_subject cs
            ON cs.subject_id = st.subject_id
        JOIN quest_rearch_production.phase_subject ps
            ON ps.subject_id = cs.subject_id
        JOIN quest_rearch_production.centre_project cp
            ON cp.centre_id = cs.centre_id
        JOIN quest_rearch_production.projects p
            ON p.id = cp.project_id
        JOIN quest_rearch_production.centre_trade ct
            ON ct.centre_id = cs.centre_id
           AND st.trade_id = ct.trade_id
    ) base
    GROUP BY base.subject_id
) agg ON agg.subject_id = s.id
LEFT JOIN (
    SELECT
        l.subject_id,
        JSON_ARRAYAGG(JSON_OBJECT('id', l.lesson_id, 'name', l.lesson_name)) AS lesson_ids
    FROM (
        SELECT DISTINCT
            id   AS lesson_id,
            name AS lesson_name,
            subject_id
        FROM quest_rearch_production.lessons
        WHERE status = 1
          AND deleted_at IS NULL
    ) l
    GROUP BY l.subject_id
) lagg ON lagg.subject_id = s.id
