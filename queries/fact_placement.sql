-- @incremental source_table=quest_rearch_production.placements id_col=id updated_at_col=updated_at dest_id_col=placement_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : fact_placement
-- Grain    : One row per learner (user_id) per placement type, selecting the
--            most recent non-deleted placement record via GROUP BY + ORDER BY.
--            Three placement type UUIDs are unioned — each branch contributes
--            at most one row per learner.
-- Mode     : incremental
-- Source   : quest_rearch_production.placements,
--            quest_rearch_production.placement_types,
--            quest_rearch_production.placement_status,
--            quest_rearch_production.sectors,
--            quest_rearch_production.centres
-- Docs     : docs/fact_placement.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    *
FROM (
    (SELECT 
        quest_rearch_production.placements.user_id AS 'pl_user_id',
        quest_rearch_production.placements.id AS 'placement_id',
        quest_rearch_production.placements.deleted_at AS 'pl_deleted_at',
        quest_rearch_production.sectors.name AS 'sector',
        quest_rearch_production.placement_status.name AS 'pl_placement_status',
        quest_rearch_production.placements.company AS 'company',
        quest_rearch_production.placements.branch AS 'branch',
        quest_rearch_production.placements.designation AS 'designation',
        quest_rearch_production.placements.sector_id AS 'sector_id',
        quest_rearch_production.placements.salary AS 'salary',
        quest_rearch_production.placements.salary_range AS 'salary_range',
        quest_rearch_production.placements.joining_date AS 'joining_date',
        quest_rearch_production.placements.updated_at AS 'pl_updated_at',
        quest_rearch_production.placements.created_at AS 'pl_created_at',
        quest_rearch_production.placements.placement_type_id AS 'pl_type',
        quest_rearch_production.placement_types.name AS 'pl_type_name',
        quest_rearch_production.placement_status.id AS 'pl_status_id',
        quest_rearch_production.placement_status.name AS 'placement_status'
    FROM
        quest_rearch_production.placements
    LEFT JOIN quest_rearch_production.placement_types ON quest_rearch_production.placement_types.id = quest_rearch_production.placements.placement_type_id
    LEFT JOIN quest_rearch_production.placement_status ON quest_rearch_production.placement_status.id = quest_rearch_production.placements.placement_status_id
    LEFT JOIN quest_rearch_production.sectors ON quest_rearch_production.sectors.id = quest_rearch_production.placements.sector_id
    LEFT JOIN quest_rearch_production.centres ON quest_rearch_production.centres.id = quest_rearch_production.placements.centre_id
    WHERE
        quest_rearch_production.placements.deleted_at IS NULL
        AND quest_rearch_production.placements.placement_type_id IN ('1627ed64-074f-4f92-9b6c-c7fb6aa0bc2c')
    GROUP BY quest_rearch_production.placements.user_id
    ORDER BY quest_rearch_production.placements.created_at DESC)
    
    UNION ALL
    
    (SELECT 
        quest_rearch_production.placements.user_id AS 'pl_user_id',
        quest_rearch_production.placements.id AS 'placement_id',
        quest_rearch_production.placements.deleted_at AS 'pl_deleted_at',
        quest_rearch_production.sectors.name AS 'sector',
        quest_rearch_production.placement_status.name AS 'pl_placement_status',
        quest_rearch_production.placements.company AS 'company',
        quest_rearch_production.placements.branch AS 'branch',
        quest_rearch_production.placements.designation AS 'designation',
        quest_rearch_production.placements.sector_id AS 'sector_id',
        quest_rearch_production.placements.salary AS 'salary',
        quest_rearch_production.placements.salary_range AS 'salary_range',
        quest_rearch_production.placements.joining_date AS 'joining_date',
        quest_rearch_production.placements.updated_at AS 'pl_updated_at',
        quest_rearch_production.placements.created_at AS 'pl_created_at',
        quest_rearch_production.placements.placement_type_id AS 'pl_type',
        quest_rearch_production.placement_types.name AS 'pl_type_name',
        quest_rearch_production.placement_status.id AS 'pl_status_id',
        quest_rearch_production.placement_status.name AS 'placement_status'
    FROM
        quest_rearch_production.placements
    LEFT JOIN quest_rearch_production.placement_types ON quest_rearch_production.placement_types.id = quest_rearch_production.placements.placement_type_id
    LEFT JOIN quest_rearch_production.placement_status ON quest_rearch_production.placement_status.id = quest_rearch_production.placements.placement_status_id
    LEFT JOIN quest_rearch_production.sectors ON quest_rearch_production.sectors.id = quest_rearch_production.placements.sector_id
    LEFT JOIN quest_rearch_production.centres ON quest_rearch_production.centres.id = quest_rearch_production.placements.centre_id
    WHERE
        quest_rearch_production.placements.deleted_at IS NULL
        AND quest_rearch_production.placements.placement_type_id IN ('e76fb44d-dfa9-45f7-a836-e868685f863e')
    GROUP BY quest_rearch_production.placements.user_id
    ORDER BY quest_rearch_production.placements.created_at DESC)
    
    UNION ALL
    
    (SELECT 
        quest_rearch_production.placements.user_id AS 'pl_user_id',
        quest_rearch_production.placements.id AS 'placement_id',
        quest_rearch_production.placements.deleted_at AS 'pl_deleted_at',
        quest_rearch_production.sectors.name AS 'sector',
        quest_rearch_production.placement_status.name AS 'pl_placement_status',
        quest_rearch_production.placements.company AS 'company',
        quest_rearch_production.placements.branch AS 'branch',
        quest_rearch_production.placements.designation AS 'designation',
        quest_rearch_production.placements.sector_id AS 'sector_id',
        quest_rearch_production.placements.salary AS 'salary',
        quest_rearch_production.placements.salary_range AS 'salary_range',
        quest_rearch_production.placements.joining_date AS 'joining_date',
        quest_rearch_production.placements.updated_at AS 'pl_updated_at',
        quest_rearch_production.placements.created_at AS 'pl_created_at',
        quest_rearch_production.placements.placement_type_id AS 'pl_type',
        quest_rearch_production.placement_types.name AS 'pl_type_name',
        quest_rearch_production.placement_status.id AS 'pl_status_id',
        quest_rearch_production.placement_status.name AS 'placement_status'
    FROM
        quest_rearch_production.placements
    LEFT JOIN quest_rearch_production.placement_types ON quest_rearch_production.placement_types.id = quest_rearch_production.placements.placement_type_id
    LEFT JOIN quest_rearch_production.placement_status ON quest_rearch_production.placement_status.id = quest_rearch_production.placements.placement_status_id
    LEFT JOIN quest_rearch_production.sectors ON quest_rearch_production.sectors.id = quest_rearch_production.placements.sector_id
    LEFT JOIN quest_rearch_production.centres ON quest_rearch_production.centres.id = quest_rearch_production.placements.centre_id
    WHERE
        quest_rearch_production.placements.deleted_at IS NULL
        AND quest_rearch_production.placements.placement_type_id IN ('aeb3bd2a-e311-4758-ac4f-2fd4334b03c0')
    GROUP BY quest_rearch_production.placements.user_id
    ORDER BY quest_rearch_production.placements.created_at DESC)
) AS combined_data