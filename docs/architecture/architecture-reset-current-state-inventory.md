# Architecture Reset — Current-State Inventory

Audit date: 2026-11-13
Repository: `LITNW/luyen-thi-tsa`
Production Supabase project: `hwqtsopvpucadgpkigqz`
Latest audited app commit: `09491537937e7c54f021328eb2ebb974fdb6de6f`

## 1. Production database snapshot (read-only audit)

All 22 public base tables inspected have RLS enabled.

| Table | Rows | Disposition |
|---|---:|---|
| profiles | 1 | KEEP — identity, role and account status |
| exams | 3 | KEEP — stable exam identities; preserve IDs |
| exam_versions | 9 | KEEP — version and publish/archive history |
| questions | 119 | KEEP — stable question identities |
| question_versions | 231 | KEEP — immutable/versioned question content |
| exam_version_questions | 358 | KEEP — exam/version-to-question mapping |
| question_answer_keys | 231 | KEEP — grading source of truth |
| attempts | 16 | KEEP — historical and active attempt records |
| attempt_answers | 16 | KEEP — submitted answers and grading |
| attempt_question_times | 64 | KEEP — per-question timing |
| attempt_question_time_events | 337 | KEEP — timing event history |
| exam_solutions | 1 | KEEP — solution content |
| subjects | 3 | KEEP, integrate into education-subject offerings |
| taxonomy_nodes | 0 | KEEP provisionally — optional learning taxonomy |
| question_version_taxonomy | 0 | KEEP provisionally — optional question classification |
| stimuli | 0 | KEEP — reusable stimuli capability |
| stimulus_versions | 0 | KEEP — immutable stimulus versions |
| exam_categories | 0 | KEEP as optional exam metadata during transition |
| import_jobs | 0 | KEEP — AI/import workflow capability |
| import_questions | 0 | KEEP — import staging |
| import_events | 0 | KEEP — import audit trail |
| audit_logs | 3 | KEEP — audit history |

Counts are a point-in-time Production snapshot. They must be rechecked immediately before any migration that changes or removes data.

## 2. Existing exam/version facts

- Three stable exam identities exist.
- All three currently have `exams.category_id IS NULL`.
- Nine exam versions exist; seven published versions are archived and two are not archived (one published and one draft in the inspected snapshot).
- Each exam identity has existing version history and associated attempts.
- The exam titles include TSA 2026–2027 mathematics and two identities titled “ĐỀ TSA 002”.
- The database does not yet record an education level, grade/program, or subject offering for these exams.
- Do not infer their exact education classification from title. Admin classification is required before the new publication rule is enabled.

## 3. M1–M3 Production migration ledger

The live Production migration ledger contains 23 entries. In particular, the following four migrations are recorded as applied:

- `20261113100000_m1_subject_taxonomy_stimuli`
- `20261113120000_exam_categories_admin`
- `20261113140000_exam_category_archived_assignment_preservation`
- `20261113150000_exam_category_admin_list_archived_version_filter`

This is a live-ledger observation; it does not identify who applied them. No migration was applied during this inventory task.

The repository's `supabase/migration-recovery-manifest.json` had stale status values marking those four migrations as repository-only. This is documentation drift and must be corrected on the architecture branch.

## 4. Application/UI findings

- `src/pages/DashboardPage.jsx` calls `list_published_exams()` and renders the returned exams directly in a flat grid on the Student home page.
- The same dashboard includes an Admin workspace and an exam-version list.
- `src/pages/AdminPages.jsx` contains the Admin category-management screen and category RPC calls.
- `src/App.jsx` exposes `/admin/categories`.
- `public/legacy/index.html` is a large retained single-file application (approximately 146 KB) containing the legacy exam room, authoring and import flows. It must not be removed until feature parity is proven.
- The React app redirects the legacy exam room and import routes into that retained page.
- PR #27 integrated category selection into the legacy editor and uses `admin_save_exam_content_with_category`.
- Student navigation does not currently consume the M1 subject catalogue or M2 category catalogue as a hierarchy.

## 5. Category-specific database objects observed

Tables/column:
- `public.exam_categories`
- `public.exams.category_id`

Functions observed:
- `admin_list_exam_categories()`
- `admin_list_exam_versions_with_categories()`
- `admin_save_exam_category(...)`
- `admin_save_exam_content_with_category(...)`
- `admin_set_exam_category(...)`
- `list_active_exam_categories()`
- `m2_set_exam_category_updated_at()`
- `m2_validate_exam_category_hierarchy()`

The category feature is not currently populated in Production. The approved target is to keep category as optional exam-purpose metadata, not as the education hierarchy. Category UI and RPCs therefore require modification, not immediate deletion.

## 6. Security baseline

- All 22 public tables have RLS enabled.
- Earlier Security Advisor review found SECURITY DEFINER functions executable by authenticated users; the Admin RPCs inspected contain internal Admin checks and are not granted to anon. Continue checking function EXECUTE grants and function bodies for every new RPC.
- Three RLS-enabled tables with no policies are deny-by-default, not public access.
- Leaked password protection warning remains an existing Auth configuration item and was not changed in this architecture task.
- No Production writes, deletes, DDL or migrations were performed during this inventory.

## 7. Known gaps / follow-up required

- Full cross-repository code-reference audit is not complete solely from the UI files inspected; inspect all SQL migrations, workflows, tests, import functions and legacy editor references before removing any category code.
- Staging data parity and backup/restore capability must be checked before data migrations.
- Existing exam education placement requires explicit Admin classification.
- CI migration recovery manifest must match the live Production ledger.
- Browser E2E of Production was not performed by the assistant; Preview checks in prior work were user-confirmed.


## 8. Education architecture reset — Staging implementation update

Staging-only migrations applied and recorded in the Staging ledger:

- `20261113155228_education_hierarchy_foundation`
- `20261113155356_education_hierarchy_active_profile_read_policies`
- `20261113155742_education_hierarchy_identity_guards`
- `20261113160130_education_exam_placement_and_scoped_catalogue`
- `20261113160231_education_exam_placement_identity_guard`
- `20261113161654_education_atomic_editor_save`

Staging now has:
- 2 education levels: THPT and Đại học.
- 0 context nodes, 0 education-subject offerings, 0 classified exams (intentionally not guessed).
- Original Staging exam/version/attempt/answer counts remain unchanged after rollback-based regression fixtures.

Regression coverage executed directly against Staging and passed:
- Education hierarchy parent/level consistency, cycle prevention, active-path constraints, stable identity protection.
- Active-profile catalogue read policies, anonymous denial and Student write denial.
- Scoped Student published-exam catalogue excludes archived versions.
- Exam placement cannot be changed once a classified exam has attempts.
- Atomic editor save persists placement before optional publication; save without a placement is rejected.

The editor and Student/Admin UI changes are present on Draft PR #28. React migration CI has passed on the previously checked head; latest changes are awaiting the next CI run. Browser E2E is not yet completed.

No Production schema or data was changed by these Staging migrations.
