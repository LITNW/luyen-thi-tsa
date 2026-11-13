# M2 implementation notes — exam categories

Status: Implemented on `feature/exam-categories-admin`; awaiting CI and review.  
Depends on M1 branch `feature/m1-subject-taxonomy-stimuli`.  
Production status: Not applied. No Production schema/data or deployment was changed.

## Data model

- `exam_categories` is separate from `taxonomy_nodes`. Categories classify the operational purpose of an exam (mock test, short quiz, semester test, revision), while taxonomy classifies the assessed learning content.
- `exams.category_id` is nullable and references `exam_categories(id)`. Category belongs to the stable exam identity, so all versions share the classification.
- Existing exams remain `NULL`; no category backfill occurs.
- `parent_id` supports optional hierarchy. Cycles are rejected and an active child requires an active parent.
- Categories are hidden by setting `is_active=false`; hard deletion is not exposed in the UI.

## RPC contracts

- `admin_list_exam_categories()`: Admin-only list, including inactive categories and exam usage count.
- `admin_save_exam_category(...)`: Admin-only create/update.
- `admin_set_exam_category(p_exam_id,p_category_id)`: Admin-only assignment/unassignment; inactive categories cannot be assigned.
- `list_active_exam_categories()`: authenticated active-user read path.
- `admin_list_exam_versions_with_categories()`: additive list contract including category metadata.
- `admin_save_exam_content_with_category(...)`: new category-aware wrapper that calls the existing six-argument `admin_save_exam_content` and assigns the category in the same transaction. The legacy RPC signature and behavior remain unchanged.

## UI

- Added an Admin category-management screen at `/admin/categories`.
- Admin can create, edit, activate, hide, and optionally nest categories.
- Admin exam list now displays category metadata and allows assigning/unassigning active categories.
- Existing editor remains available; the new category-aware save RPC is ready for clients that adopt it. Existing exams can also be classified from the Admin exam list.

## Safety and tests

- RLS allows authenticated students to read active categories only. All writes are Admin-only.
- Category assignment locks the active category row to avoid a concurrent archive race.
- Tests cover nullable legacy exams, create/update, slug uniqueness, hierarchy/cycle protection, archive rules, assignment, category-aware save, Admin/student RLS, and legacy RPC compatibility.
- Migration is additive and does not modify `attempts`, `attempt_answers`, or historical attempt records.
- No Storage bucket or Production migration is involved.
