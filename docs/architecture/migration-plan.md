# Multi-subject platform — migration and compatibility plan

Status: Proposed; no database migration in this document has been applied.  
Target: current `main` branch and the existing Supabase Production schema.  
Strategy: Expand → Backfill → Dual-read/dual-write where required → Switch → Contract.

## 1. Safety boundaries

- No Production SQL writes, migration repair, `db push`, or schema changes as part of the planning phase.
- Never edit or reorder the 17 recovered Production migration files.
- Preserve `20261112050000_ai_exam_import_staging.sql` and `20261112170000_centralize_exam_answer_validation.sql` in their current chronological order.
- New migration timestamps must be later than `20261112170000` and must be unique.
- Do not add a reconstructed historical baseline to the active migration directory.
- The test-only pre-005 fixtures remain test-only.
- Do not change or delete data in `attempts`, `attempt_answers`, `exam_version_questions`, `question_versions`, or `question_answer_keys` in P0/P1.

## 2. P0 — before the first schema migration

### Required inventory
- Table/column definitions, PK/unique/check/FK constraints.
- Indexes, triggers, RLS state and policies.
- Function definitions, SECURITY DEFINER flags, grants, search_path.
- Current RPC payloads used by the React and legacy clients.
- Existing migration manifest, clean-install workflow, PostgreSQL workflow, and all current regression tests.
- Existing import workflow assumptions about question content.
- Current Storage buckets/policies and Edge Function deployment state.

### Required artifacts
- `docs/architecture/multi-subject-platform.md`
- `docs/architecture/current-schema-audit.md`
- `docs/architecture/migration-plan.md`
- ERD and explicit RPC compatibility matrix.
- RLS matrix for each new table and RPC.
- Data invariants and backfill verification SQL.
- Rollback/forward-fix notes for every migration.

### P0 exit gate
No migration is authored until:
1. All legacy contracts have a named owner and test.
2. The exact relationship between `exam_version_questions`, `attempt_answers`, and timing tables is documented.
3. Group membership-to-exam-mapping invariants are enforceable transactionally.
4. RLS and student answer-key isolation are specified.
5. A clean-install fixture can exercise the proposed schema in the same sequence as CI.

## 3. Migration sequence

### M1 — subject and taxonomy foundation
Add:
- `subjects`
- `taxonomy_nodes`
- `question_version_taxonomy`

No old question is assigned automatically. Seed only stable subject codes after content ownership confirms the taxonomy. Existing question versions remain valid with no taxonomy links.

### M2 — reusable stimulus foundation
Add:
- `stimuli`
- `stimulus_versions`
- required immutability triggers and RLS

Do not add question-to-stimulus links until the stimulus lifecycle and storage access rules are tested. Do not copy existing question text into stimulus rows automatically.

### M3 — question group versioning
Add:
- `question_groups`
- `question_group_versions`
- `question_group_version_questions`

Enforce immutable published group versions and unique ordered membership. Mixed question types are allowed; answer-key validation remains per question.

### M4 — exam sections and structure
Add:
- `exam_sections`
- `exam_section_items`
- `exam_section_item_questions`

Backfill each existing `exam_versions` row to a default section and one standalone item per existing `exam_version_questions` row. The backfill must not update or recreate any `exam_version_questions.id`, question version, answer key, attempt, or answer row.

Before applying:
- Count expected mapping rows by exam version.
- Ensure each mapping has a valid unique `position`.
- Ensure every mapping can be assigned to exactly one section item.
- Verify there are no duplicate positions or mappings.
- Verify each `exam_version_questions` row appears exactly once after backfill.
- Verify existing attempt foreign keys remain valid.
- Verify existing published exams still return the same flat question order through `get_published_exam`.

The backfill is a deterministic representation of the existing flat layout, not an editorial change to published exams.

### M5 — structured RPCs
Add versioned RPCs without changing old RPC signatures:
- `get_published_exam_v2`
- `admin_get_exam_structure_v2`
- `admin_save_exam_structure_v2`

The v2 save path must be one transaction. It must lock the draft exam version, validate the section/item tree, reconcile mappings without replacing unchanged mapping IDs, validate group membership and answer keys, and publish only after complete validation.

Do not let old `admin_save_exam_content` accept a structured payload by guessing from JSON shape. Keep it flat and explicit until the old editor is retired.

### M6 — application switch
- Add a frontend feature flag for structured exam authoring/runtime.
- Test legacy exams through the old RPC and new exams through v2.
- Compare normalized v2 content against the legacy flat payload for single-section, no-group exams.
- Switch admin authoring first, then runtime rendering.
- Keep legacy runtime available until resume, offline sync, timing, submission, and results parity is verified.

### M7 — question types and grading
Only after M1–M6:
- Introduce a registry for question schemas/renderers/validators/graders.
- Expand the database CHECK constraint deliberately.
- Add each new type in a separate testable unit.
- Keep all five existing types unchanged.
- Version grading strategies/configuration so historical attempts are not regraded implicitly.

## 4. Backfill and compatibility checks

For M4, require these assertions:
- `count(exam_section_item_questions) = count(exam_version_questions)` for all migrated versions.
- Each `exam_version_question_id` is referenced exactly once.
- Each section item belongs to the same `exam_version_id` as its mapped question.
- For every old exam version, flattening sections/items produces the same ordered tuple:
  `(mapping_id, question_version_id, question_id, position, points)`.
- `attempt_answers` row count and all existing FK relationships are unchanged.
- Every historical attempt retains its `exam_version_id`, status, score, max_score, elapsed time, and submitted timestamp.
- Student RPC responses contain no answer key or grading-only metadata.

## 5. Test matrix

### Database
- PostgreSQL 16 clean install.
- Supabase local clean install with Auth/Storage schemas.
- Migration replay and idempotency where applicable.
- FK, unique, check, trigger, and immutability tests.
- RLS tests for anon, authenticated student, admin, and service role.
- SECURITY DEFINER grants and empty search_path tests.

### Legacy compatibility
- Existing flat exam read.
- Existing draft save/edit/publish.
- Start/resume/reload/reconnect.
- Save each answer type.
- Time event idempotency.
- Submit idempotency and authoritative score.
- History and result details.
- Existing published exam order and content parity.

### Structured content
- One stimulus reused by two different groups.
- One group containing MC, MS, TF, NUM, and DND.
- A section with standalone questions and groups.
- Multi-subject exam with section subject labels.
- Editing a stimulus creates a new version and does not alter published exams.
- Editing group membership creates a new group version.
- Attempt answers remain keyed by existing exam mapping IDs.

### Failure and security
- Reject group membership that does not match the referenced group version.
- Reject duplicate mapping assignment.
- Reject empty group items.
- Reject section/item edits on published exam versions.
- Reject student access to answer keys and unpublished stimuli.
- Reject unauthorized Storage upload/download.
- Reject partial save; transaction must roll back as a unit.

## 6. Rollback approach

- Before a migration is applied anywhere, test rollback against the isolated local stack.
- For additive migrations, rollback means disabling the new RPC/feature flag first; dropping newly created tables is not the default rollback if data may have been written.
- After user data or authored content is created in new tables, prefer a forward-fix. Do not drop content-bearing tables as a routine rollback.
- Never reverse a production migration automatically. Any Production rollback requires a separate reviewed plan and explicit approval.
- Keep old RPCs and legacy runtime until parity is established.

## 7. PR policy

- One PR per architectural phase.
- PRs changing SQL include migration, tests, RLS/grants, clean-install workflow updates, and documentation together.
- Keep architecture docs separate from implementation migrations.
- Avoid stacking dependent PRs on stale branches; rebase/branch from current `main`.
- Close or supersede stale PRs only when their purpose is fully represented elsewhere. PR #18 is a separate hotfix targeting `supabase-migration`, so it is not a candidate for retargeting into this work. PR #20's structural HTML test is unrelated and remains separately reviewable.
