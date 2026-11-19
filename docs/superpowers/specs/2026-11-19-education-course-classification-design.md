# Education course classification redesign

## Intent

Replace the active education hierarchy for LIT course setup, exam authoring, and student browsing. THPT courses are direct children of a level. University courses belong to editable, level-scoped groups. Exams continue to reference concrete `education_subjects` rows by their existing IDs.

## Goals and constraints

- Preserve `education_subjects.id`, `exams.education_subject_id`, course details, and unrelated subject/taxonomy features.
- Seed default university groups idempotently and place existing university courses in the neutral group without inferring from names.
- Require a valid same-level group for university courses and keep THPT courses ungrouped.
- Replace active React and legacy UI classification paths; retain old hierarchy storage until code, SQL RPCs, policies, and tests have been proven independent.
- Do not write to Staging or Production, merge, or deploy.

## Approaches

1. Add groups in parallel while leaving old UI active: low migration risk, but fails the single-authoritative-workflow requirement.
2. Replace the active workflow with level-scoped groups and keep legacy database structures as compatibility storage until a later verified retirement: preserves IDs and protects older SQL consumers while switching all active UI. **Selected** because existing SQL guards/RPCs and old tests still directly require node and catalogue fields.
3. Drop nodes, `subject_id`, and `knowledge_group` immediately: cleanest schema, but would break current migrations, RPCs, tests, and exam placement before their dependency chain is replaced.

## Design

Add `education_subject_groups` with UUID identity, level-scoped code, name, optional description, order, status, and timestamps. Add nullable `education_subjects.group_id` with a composite same-level foreign key. Make the legacy `subject_id` link nullable so new concrete courses are independent records; preserve all existing values. A trigger requires a group for university courses, prohibits groups for THPT courses, and checks active level/group membership. Existing university rows are backfilled to `unclassified`; THPT rows get NULL. Existing node and shared-subject columns remain compatibility fields and are no longer read or written by the active education UI.

Admin education management will edit groups and direct courses. Exam authoring and assignment will present the level → group → course path only for university and level → course for THPT. Student browse pages will show groups for university and courses directly for THPT. Old `/context/:nodeId` URLs get an intentional redirect to the corresponding level page; existing `/subject/:offeringId` URLs remain valid.

## Recovery and verification

The migration is transactional where supported by PostgreSQL and is forward-only after data has been written: recover from a bad rollout by restoring the pre-migration snapshot and reapplying a corrected migration, or by a new forward migration. The recovery manifest and clean-install CI must include the new migration. SQL tests assert ID/reference preservation and assignment rules. Existing node/catalogue SQL contracts are retained and documented until their independent retirement is safe.
