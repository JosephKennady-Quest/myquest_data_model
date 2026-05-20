# fact_lesson_progress Query Documentation

Source query: `queries/fact_lesson_progress.sql`

> **Draft / stub — no SQL implemented yet.** The query file currently contains only a list of planned output column names. This document describes the intended structure of the `fact_lesson_progress` table based on those planned columns. All sections below reflect the planned design and are subject to change once the SQL is written.

This table is intended to capture per-learner, per-lesson progress records, tracking completion status, time spent, and attempt counts for each lesson a learner has engaged with. It will serve as a granular engagement fact table, supporting lesson-level analysis across the learner, lesson, course, and subject dimensions.

## Query Grain

Planned grain: one row per learner-lesson combination (`progress_id`). Fan-out risks cannot be assessed until the SQL is written. The presence of a surrogate `progress_id` suggests the grain may be one row per progress record rather than strictly one per learner-lesson pair.

## Incremental Configuration

This section will be populated once the SQL and `@incremental` configuration are written. No incremental settings have been defined yet.

## Global Filters

No global filters defined yet. This section will be populated once the SQL is written.

## Output Columns

The following columns are planned based on the stub file. Nullability, source tables, and transform logic are not yet defined.

| Output column | Source table | Source column | Transform / logic | Reason for inclusion | Nullable in query |
| --- | --- | --- | --- | --- | --- |
| `progress_id` | TBD | TBD | Surrogate or source primary key for the progress record. | Primary grain key for the fact table. | TBD |
| `user_id` | TBD | TBD | Foreign key linking to the learner dimension. | Identifies the learner associated with the progress record. | TBD |
| `lesson_id` | TBD | TBD | Foreign key linking to the lesson. | Identifies the lesson being tracked. | TBD |
| `course_id` | TBD | TBD | Foreign key linking to the course. | Supports course-level rollup of lesson progress. | TBD |
| `subject_id` | TBD | TBD | Foreign key linking to the subject dimension. | Supports subject-level analysis. | TBD |
| `time_spent_secs` | TBD | TBD | Total time spent on the lesson, in seconds. | Core engagement metric for lesson-level analytics. | TBD |
| `completed_flag` | TBD | TBD | Boolean or integer flag indicating lesson completion. | Used to filter and measure completion rates. | TBD |
| `attempts` | TBD | TBD | Count of attempts on the lesson. | Supports difficulty and engagement analysis. | TBD |
| `completed_at` | TBD | TBD | Timestamp when the lesson was completed. | Enables time-based completion analysis. | TBD |

## Entity Relationship Diagram

Not available — SQL not yet implemented. ERD will be added once the query is written.

## Join and Cardinality Notes

Not available — SQL not yet implemented.

## DWH Interpretation

| Item | Value |
| --- | --- |
| Intended DWH table | `fact_lesson_progress` |
| DWH grain risk | Cannot be assessed until SQL is implemented. Planned grain is one row per progress record (`progress_id`). |
| Production source schema | `quest_rearch_production` |
| DWH source status | The query will read from production source tables, not DWH tables. |
| Output DWH columns | `progress_id`, `user_id`, `lesson_id`, `course_id`, `subject_id`, `time_spent_secs`, `completed_flag`, `attempts`, `completed_at` |
