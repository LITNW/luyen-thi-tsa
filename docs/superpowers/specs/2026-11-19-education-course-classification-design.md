# Education course-category design

## Intent

Implement the current PR #41 owner-approved model for LIT course setup, exam authoring, and student browsing:

- THPT: `Education level → Course` (flat).
- University: `Education level → Course category → Course`.

Exams continue to reference concrete `education_subjects` rows by their existing IDs.

## Goals and constraints

- Course categories are ordinary records managed by Admin. They are not a fixed enum, not tied to a major, and not a shared subject catalogue.
- Seed exactly one neutral default University category: `Chưa phân loại`. Do not seed example taxonomy values. Do not guess existing course classifications.
- Preserve `education_subjects.id`, `exams.education_subject_id`, course details, and unrelated subject/taxonomy features.
- University courses must have one active category from the same education level. THPT courses must have `category_id IS NULL`.
- New concrete courses do not require a shared `subjects` catalogue row; make the legacy `subject_id` nullable while retaining existing values.
- Replace the active React and legacy UI classification paths; retain old hierarchy/catalogue storage until code, SQL RPCs, policies, and tests have been proven independent.
- Do not maintain the superseded `education_subject_groups` / `group_id` workflow alongside the category workflow.

## Design

Create `education_course_categories` with UUID identity, level-scoped code, name, optional description, display order, active status, and timestamps. The code is editable text with uniqueness scoped to an education level; it is not an enum.

Add nullable `education_subjects.category_id` with a composite same-level foreign key. Seed only the neutral `unclassified` category for University. Backfill every existing University course into that category, leaving THPT courses unassigned. Never alter course UUIDs or exam references.

A trigger requires a category for University courses, prohibits categories for THPT courses, and checks that the category belongs to the same level and is active when the course is active. RLS permits active profiles to read active education records and preserves the existing Admin bypass for category management. Category deletion is restricted by dependent courses; deactivation requires active courses to be moved or deactivated first.

Admin education management creates and edits categories and concrete courses. Exam authoring and assignment present level → category → course only for University and level → course for THPT. Student browse pages show categories for University and courses directly for THPT. The exam RPC receives only the concrete course UUID and continues to persist it as `exams.education_subject_id`.

Existing node and shared-subject columns remain compatibility fields until their individual SQL/RPC dependencies are replaced and covered by follow-up migrations. They are no longer read or written by the active education UI.

## Recovery and verification

The migration is additive and transactional. It preserves the existing course primary keys and exam foreign keys. Once new categories/courses have been written, recovery should prefer a reviewed forward migration or a separately approved Staging restore; do not drop category data or rewrite IDs as an automatic rollback.

The recovery manifest and clean-install/recovered-chain CI include the category migration. SQL tests assert exactly one default category, freeform Admin-created categories, same-level assignment, THPT flat behavior, RLS, and identity preservation. Hosted Staging application is blocked until the reconstructed migration history has been reconciled from SQL fingerprints and live schema evidence. Production remains out of scope.
