# M3 — Integrate exam categories into the legacy editor

Status: Draft PR #27; CI is running on `feature/exam-category-editor-integration`.  
Base: `feature/exam-categories-admin` (PR #26).  
Production: No migration or deployment has been performed.

## Editor behavior

- Creating an exam loads active categories through `list_active_exam_categories()`.
- Opening an existing version loads the exam's current category from `admin_list_exam_versions_with_categories()`.
- The category select allows an empty value. On a new or already unclassified exam, empty means `exams.category_id IS NULL`; on an already classified exam, choosing “Không phân loại” explicitly removes the assignment.
- Existing published versions still follow the legacy workflow: the editor creates a draft version before editing.
- Saving uses `admin_save_exam_content_with_category(...)`; the six-argument legacy `admin_save_exam_content` contract is not modified.
- The selected category is retained in the editor state after saving a draft.
- AI-import-to-editor also loads the active category list before showing the editor.

## Backward compatibility

- Existing uncategorized exams open with “Không phân loại”. Saving without selecting a category sends `NULL`, so the exam remains uncategorized.
- Existing active category assignments are preselected; choosing “Không phân loại” explicitly unassigns the category.
- If an assigned category has since been archived, the editor shows a disabled current-value option. The M2 wrapper permits preserving that exact existing assignment while editing the exam, but rejects assigning an inactive category to a different exam. This behavior is delivered by the append-only follow-up migration `20261113140000_exam_category_archived_assignment_preservation.sql`; the original M2 migration `20261113120000_exam_categories_admin.sql` remains unchanged.
- Question mapping identity logic remains unchanged: the editor continues to carry forward existing `mapping_id` and `question_id` values when constructing the save payload.

## Student access semantics

Categories are organizational metadata, not a publication gate. Student category reads expose active categories only through RLS and `list_active_exam_categories()`. The published-exam RPC continues to expose published legacy exams, including those whose category is NULL, and does not expose category metadata. This is deliberate to avoid hiding historical/legacy exams.

## Regression coverage

- Node test parses the legacy inline JavaScript and checks that the category read RPC, select control, save wrapper, NULL fallback, and existing-category state are wired.
- PostgreSQL/Supabase regression checks the M2 wrapper, inactive-category preservation, active-category student reads, denied student writes, and Admin-only RPC permissions.
- Existing legacy exam contract regression continues to exercise the old save RPC and mapping ID retention.
- CI includes React migration CI, Supabase clean-install compatibility, recovered PostgreSQL migration chain, and migration recovery integrity.

## Scope exclusions

- No changes to `attempts`, `attempt_answers`, answer keys, scoring or submission RPCs.
- No Storage bucket changes.
- No Production database migration, Production DDL/DML, or deployment.
- No automatic classification/backfill of legacy exams or questions.
