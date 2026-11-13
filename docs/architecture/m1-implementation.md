# M1 implementation notes

Status: Implemented on `feature/m1-subject-taxonomy-stimuli`; awaiting CI and review.  
Parent architecture: PR #24 (`architecture/multi-subject-foundation`).  
Production status: Not applied. No Production schema/data or Storage bucket was touched.

## Included

- `subjects`: stable subject codes and display metadata; seeded with Mathematics, Reading, and Science.
- `taxonomy_nodes`: subject-scoped hierarchy with a composite same-subject parent FK, root/child code uniqueness, cycle prevention, and referenced-identity protection.
- `question_version_taxonomy`: immutable historical classification after a question version appears in a published exam; one primary topic per question version; relation type must match taxonomy node type.
- `stimuli`: reusable identity and lifecycle state.
- `stimulus_versions`: structured JSON content and metadata, unique version numbers, immutable after insert.
- RLS enabled on all five tables. Admin-only direct table policies; students receive the active subject catalogue through `list_active_subjects()`. Anonymous execution is revoked.
- Indexes for subject hierarchy traversal, taxonomy lookup, classification lookup, stimulus status and stimulus-version lookup.

## Explicitly excluded

- No automatic subject/taxonomy assignment for existing question versions.
- No changes to `exams`, `exam_versions`, `questions`, `question_versions`, `attempts`, `attempt_answers`, or legacy exam RPC contracts.
- No Storage bucket or Storage policy changes.
- No category management schema or RPC changes.
- No Production migration execution.

## Regression coverage

The M1 regression script checks subject seeds, no backfill, same-subject parent enforcement, cycle rejection, root code uniqueness, relation-type matching, one-primary-topic constraint, taxonomy identity protection, published-question classification immutability, stimulus-version immutability, student/admin RLS, and the active-subject RPC boundary.

The clean-install workflow applies M1 after the recovered chain, AI import migration, and centralized answer-validation migration. The PostgreSQL-only workflow applies the same SQL migration after the recovered chain and answer-validation migration. Both workflows run the M1 regression script; the Supabase local workflow also retains the legacy exam RPC regression.

## Follow-up: exam categories

Exam categories are intentionally a separate migration/PR because they alter the existing exam domain and authoring contract. The current proposal is a dedicated `exam_categories` table and nullable `exams.category_id` FK (category belongs to the stable exam identity, not each version). Preserve the legacy `admin_save_exam_content` signature; add a separately named category-aware admin RPC or an explicit category assignment RPC rather than silently changing the legacy contract. Implement admin-only category management, active-category listing, and compatibility tests in that follow-up. Existing exams remain uncategorized until explicitly assigned.
