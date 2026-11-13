# Current schema audit — multi-subject restructuring

Audit date: 2026-11-13  
Project: `hwqtsopvpucadgpkigqz`  
Repository: `LITNW/luyen-thi-tsa`  
Branch baseline: `main` at `46cb00c447b49edae055e2d8b25be7bf09bcc561`

## 1. Scope and safety

This audit used read-only schema, migration-ledger, RPC, constraint, and row-count inspection. It did not execute DDL/DML against Production. No schema, migration ledger, exam, question, answer key, profile, or attempt data was modified.

## 2. Current migration baseline

- The recovered Production migration chain contains 17 ledger migrations through `20261112041845`.
- `20261112050000_ai_exam_import_staging.sql` is pending, not in the Production ledger.
- `20261112170000_centralize_exam_answer_validation.sql` is the answer-validation migration now merged to main.
- PR #23 and PR #22 are merged.
- The clean-install workflow originally fetched PR #22 from its feature branch. PR #24 removes that dependency and applies the migration/test files from the checked-out commit; it also broadens test path filters to `supabase/tests/**`.

The reconstructed pre-005 fixture is a compatibility fixture, not a recovered exact historical baseline for migrations 001–004.

## 3. Observed current entities

Core tables include:
- Identity and audit: `profiles`, `audit_logs`
- Legacy content: `exams`, `exam_solutions`
- Versioned content: `exam_versions`, `questions`, `question_versions`, `question_answer_keys`, `exam_version_questions`
- Attempts: `attempts`, `attempt_answers`, `attempt_question_times`, `attempt_question_time_events`
- Import staging: `import_jobs`, `import_questions`, `import_events`

Observed row counts at the time of review:
| Table | Rows |
|---|---:|
| `exams` | 3 |
| `exam_versions` | 8 |
| `questions` | 119 |
| `question_versions` | 231 |
| `question_answer_keys` | 231 |
| `exam_version_questions` | 318 |
| `attempts` | 15 |
| `attempt_answers` | 16 |

Question-version type distribution:
| Type | Count |
|---|---:|
| `mc` | 93 |
| `ms` | 14 |
| `tf` | 49 |
| `num` | 42 |
| `dnd` | 33 |

Counts are observational only and will change as the platform is used.

## 4. Critical schema contracts

### Question versions
- `question_versions.content` is JSONB constrained to an object containing key `q`.
- `question_versions.question_type` has a CHECK constraint allowing exactly `mc`, `ms`, `tf`, `num`, `dnd`.
- `question_versions` is versioned by `(question_id, version_no)`.
- `question_answer_keys` is a one-to-one separate table keyed by `question_version_id`, with restrictive deletion semantics.

### Exam mappings
- `exam_version_questions` maps a question version into a specific exam version.
- Unique constraints protect per-exam position and per-exam question-version membership.
- The composite FK from `exam_version_questions(question_version_id, question_id)` to `question_versions(id, question_id)` preserves identity consistency.
- The composite FK to `exam_versions(id, exam_id)` preserves exam ownership consistency.

### Attempts
- `attempts` stores `exam_version_id` and `exam_id` under a composite FK to `exam_versions`.
- `attempt_answers` references `attempts(id, exam_version_id)` and `exam_version_questions(id, exam_version_id)`.
- `attempt_answers` has unique `(attempt_id, exam_version_question_id)`.
- This is why group/section structure must map to existing `exam_version_questions.id`, not replace it.

### RPC contracts
- `get_published_exam(uuid)` returns a flat question list with mapping ID, position, points, type, and public content.
- `admin_get_exam_version(uuid)` returns flat questions and answer-key fields for admin authoring.
- `admin_save_exam_content(..., p_questions jsonb, ...)` accepts a flat array and reconciles mapping IDs; it deletes mappings omitted from the submitted array.
- `admin_create_exam_version` clones flat mappings only. `admin_delete_exam_version` deletes mappings before the parent version when no attempts exist.
- `list_published_exams` does not return a content-model/runtime version. `get_my_attempt_state` returns the exact exam version ID but not its layout version.
- `submit_exam_attempt(uuid)` grades by iterating `exam_version_questions`; it remains the authoritative score writer.
- The flat add/remove/replace/reorder RPCs mutate `exam_version_questions` directly. The points-only RPC updates a mapping without understanding section/group structure.
- Answer-save, resume, time-tracking, and history RPCs rely on existing mapping and attempt identifiers.

## 5. Immutability, import, and media observations

- Triggers prevent UPDATE/DELETE on `questions`, `question_versions`, and `question_answer_keys`; published exam versions and their question mappings are protected as well. New stimulus links must be written when creating a new question version, not by rewriting historical rows.
- All 16 observed public application tables have RLS enabled, but `FORCE ROW LEVEL SECURITY` is not enabled. Service-role/server-side paths still require careful authorization and secret handling. Several sensitive tables intentionally have no direct student SELECT policy and are mediated through RPCs.
- The current `storage.objects` policies grant admin-only access to the private `tsa-imports` bucket; there is no student media-read policy to reuse for stimuli.
- The existing private Storage bucket `tsa-imports` has a 25 MiB file-size limit and no MIME allowlist. Keep it dedicated to import source files; do not mix reusable stimulus assets into it.
- The import staging model (`import_jobs`, `import_questions`, `import_events`) stores extracted question content/answer keys and source metadata but has no first-class stimulus or question-group references. The importer must be extended deliberately after the content model is stable.
- All 231 observed question versions contain a string prompt and options array; none has a detected top-level `stimulus` field. Do not assume that historical content already has reusable passages or media.

## 6. RLS and security observations

RLS is enabled on the existing application tables. Some sensitive tables intentionally have no direct student SELECT policy and are accessed through server-side RPCs. New content and stimulus tables must not accidentally grant direct student access to answer keys or draft content.

A separate security review is required for:
- New RLS policies and grants.
- SECURITY DEFINER function ownership and execute grants.
- `search_path` hardening.
- Storage bucket policies and signed URL rules.
- Student-facing RPC output allowlists.

Do not treat the presence of RLS alone as proof of correct access control.

## 7. Known migration and CI concern

The clean-install workflow source on main fetches PR #22's migration and test from branch `fix/exam-answer-validation-guard` and asserts a hard-coded head SHA. Since PR #22 has been merged, the workflow should instead consume the migration and test files already present in the checked-out commit. This removes an unnecessary dependency on the continued existence and immutability of a feature branch. This CI cleanup should be done as a small, isolated change before the first new schema migration.

## 8. Open PR disposition

- PR #18: separate hotfix for the obsolete `supabase-migration` branch. Its own description explicitly says not to retarget it to main. Leave it isolated; do not merge it into this architecture work.
- PR #20: structural regression test for the active legacy exam HTML. Its CI run for the PR head completed successfully, but its branch is now 84 commits behind and 2 commits ahead of current main. Do not merge that stale branch wholesale. Port the 12-line test onto a fresh branch from current main, then close PR #20 as superseded, or leave it draft until that isolated replacement is ready.
- PR #22 and #23: merged; their migration files and tests are now part of the baseline.
