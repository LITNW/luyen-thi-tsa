# Education course classification cutover audit

Date: 2026-11-19. Repository: PR #41, branch `fix/education-empty-uuid-payload`.

## Active consumers moved to groups

- `src/pages/AdminEducationPage.jsx`: direct THPT course management and level → group → course management for University.
- `src/pages/AdminPages.jsx`: exam assignment selector and placement summary now resolve concrete courses through groups.
- `public/legacy/index.html`: legacy React-independent exam editor now loads levels, groups and courses; validates level/group/course consistency on save.
- `src/pages/EducationBrowsePages.jsx` and `src/App.jsx`: student routes show direct THPT courses and University groups/courses. The former `/education/:levelCode/context/:nodeId` route redirects to the level page; existing `/subject/:offeringId` links remain valid.

## Legacy schema dependency map

`education_nodes`, `education_subjects.education_node_id`, and the old `subjects` relation remain in the database for now. The repository still has education hierarchy triggers and identity guards, education placement and publication guards, the atomic editor RPC, multiple regression SQL fixtures, and taxonomy/stimulus features that depend on these fields or tables. Their historical behavior cannot be removed safely in this cutover migration. `education_subjects.subject_id` is made nullable for newly created direct courses; existing values and global taxonomy data remain intact.

The global `subjects` and `taxonomy_nodes` tables remain necessary for the separate M1 taxonomy/stimulus features. They are no longer selected or written by education course administration or exam authoring. Legacy columns and SQL dependencies are deliberately retained as compatibility storage until those individual consumers are replaced and covered by follow-up migrations.

## Migration disposition

The branch-only `20261119130000_allow_multiple_offerings_per_catalogue_subject.sql` and `20261119150000_add_education_knowledge_groups.sql` migrations were not applied to either hosted database and have been removed from the active chain. They are recorded as superseded in `supabase/migration-recovery-manifest.json`. The new `20261119160000_education_subject_groups.sql` is an additive, transactional migration and is pending PR #41 only.

The replacement migration preserves course primary keys and exam foreign keys by adding a nullable `group_id`, backfilling existing University rows to the neutral group, and never deleting/recreating a course or updating `exams.education_subject_id`. The same-level composite foreign key prevents cross-level group assignment; a trigger enforces University group membership and THPT null groups; `ON DELETE RESTRICT` and guards prevent silent group/course loss.

## Hosted baseline and limits

Read-only Supabase queries on 2026-11-19 confirmed neither superseded nor replacement PR #41 education migration is present in either migration ledger. Before this migration is applied, Staging had 2 courses (1 THPT, 1 University), 3 exams linked to a course, and 0 broken exam-course references. Production had 1 THPT course, 4 exams linked to a course, and 0 broken exam-course references. The pre-migration IDs and row contents are in the live database and were not modified during this task.

The post-migration row counts, ID preservation counts, group distribution, and student runtime behavior have not yet been verified because the migration was intentionally not applied to Staging or Production. The local machine had no PostgreSQL client or running Docker daemon, so SQL regression and clean-install execution remain CI checks. The existing Preview is documented in PR #41 as frontend/database schema out of sync, so it is not valid runtime evidence.
