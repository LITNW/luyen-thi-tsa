# Education course-category cutover audit

Updated: 2026-11-22. Repository: PR #41, branch `fix/education-empty-uuid-payload`.

## Authoritative product decision

The PR owner updated PR #41's description at 2026-11-19 16:43:16Z, after the last implementation commit at that time. That description is the latest confirmed product decision; no newer migration or review has superseded it.

- THPT: `Education level → Course`; no category.
- University: `Education level → Course category → Course`.
- Categories are ordinary, level-scoped records created and managed by Admin. They are not a fixed enum, a major taxonomy, or a shared subject catalogue.
- Seed only one neutral University category: `Chưa phân loại`. Existing University courses are assigned there without guessing their classification. Admin may later create, edit, reorder, deactivate, and reassign categories.
- A course is one concrete selectable record. Exams continue to reference it through `exams.education_subject_id`.

## Active consumers

- `src/pages/AdminEducationPage.jsx`: Admin manages University categories and concrete courses; THPT courses remain direct.
- `src/pages/AdminPages.jsx`: exam placement uses level → category → course for University and level → course for THPT.
- `public/legacy/index.html` and `public/legacy/education-classification.js`: legacy exam editor uses the same selector contract.
- `src/pages/EducationBrowsePages.jsx` and `src/App.jsx`: student browsing uses the same hierarchy and direct course links.

## Schema contract

The target migration is `20261119160000_education_course_categories.sql`.

- Create `education_course_categories` with UUID identity, `education_level_id`, editable text `code`, name, description, display order, active status, and timestamps.
- Add nullable `education_subjects.category_id` with a composite same-level foreign key.
- Make legacy `education_subjects.subject_id` nullable for self-contained course records; do not rewrite existing values.
- Enforce University category membership and THPT `category_id IS NULL` with a trigger.
- Preserve all `education_subjects.id` values and every `exams.education_subject_id` reference.
- Use RLS: active profiles can read active levels/categories/courses; Admin retains management access. No temporary write-freeze policy is part of the target design.

## Compatibility boundary

`education_nodes`, `education_subjects.education_node_id`, `subject_id`, and the global `subjects` / `taxonomy_nodes` structures remain for legacy SQL/RPC and the separate M1 taxonomy/stimulus feature until their dependencies are individually retired. The new education workflow must not query or write the shared subject catalogue. Do not drop compatibility fields in this migration.

## Hosted environment status

- The old `education_subject_groups` migration was never applied and is superseded. Do not deploy it.
- The new category migration is pending PR #41; it has not been applied to Staging or Production.
- The Staging migration ledger has reconstructed and Staging-only versions that do not map one-to-one to local filenames. A normal `db push` dry-run failed on remote-only versions. Reconcile this history with SQL fingerprints and live schema evidence before any Staging migration. Do not use `migration repair`, `--include-all`, or manual ledger edits as a shortcut.
- Staging's obsolete temporary University write-freeze policies are absent. Do not recreate them.
- Production is reference-only and remains untouched. PR #41 must remain open and Draft until review and Staging verification are complete.

## Required verification

The disposable SQL regression and clean-install/recovered-chain CI must prove the one-default-category seed, freeform category creation, same-level membership, THPT flat behavior, RLS, and preservation of course/exam identities. After the history blocker is resolved, Staging verification must compare the pre/post course UUID set and exam references, then smoke-test Admin, exam editor, and student browse against the Staging Supabase ref.
