-- @incremental source_table=quest_rearch_production.programs id_col=id updated_at_col=updated_at dest_id_col=program_id
-- ─────────────────────────────────────────────────────────────────────────────
-- Table    : dim_program
-- Grain    : one row per program (no joins, no fan-out risk)
-- Mode     : incremental
-- Source   : quest_rearch_production.programs
-- Docs     : docs/dim_program.md
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
	p.id AS program_id,
	p.name,
    p.updated_at
FROM
	quest_rearch_production.programs p
WHERE
	1 = 1
	AND p.status = 1
	AND p.deleted_at IS NULL