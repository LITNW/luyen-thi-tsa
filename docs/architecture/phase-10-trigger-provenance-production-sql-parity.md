# Phase 10 — Trigger Provenance & Production SQL Parity Audit

**Date:** 2026-11-15 (Asia/Ho_Chi_Minh)  
**Repository baseline:** `LITNW/luyen-thi-tsa` / `main`  
**Baseline commit:** `92856f1bc65cfa2a4c8a96ab17480a554dc64aba`  
**Scope:** Read-only GitHub and Supabase catalog inspection. Documentation-only repository change on a separate branch.

## Executive summary

1. Production and Staging frontend-to-project mapping was established in Phase 9; this phase compared live SQL catalogs directly. No DDL, migration, DML, RPC invocation, grant change, deployment, or secret change was performed.
2. Public function catalog is **74 in Production vs 72 in Staging**. Auth has 4 in each; Storage has 24 in each.
3. Non-internal triggers are **34 public + 1 auth + 11 storage in Production** and **33 public + 1 auth + 11 storage in Staging**. The single public trigger present only in Production is `attempt_question_times.attempt_question_times_guard`.
4. RLS policies are identical by key and normalized catalog definition in the queried schemas: **42 public + 4 storage policies** in each project (46 total).
5. Five public function definitions differ by hash: two Production-only functions and three same-signature functions with differing definitions. Two differences are clearly environment-specific bootstrap/profile behavior; `submit_exam_attempt(uuid)` requires a focused semantic diff before being declared equivalent.
6. The current repository migration set and archive do not yet establish complete provenance for every live trigger attachment. Selected migration files contain trigger-function definitions but no matching `CREATE TRIGGER` statements for the guards examined. Do not remove or recreate any of them based on this report.
7. The migration manifest contains historical status statements that conflict with the live Production migration ledger for the education migrations. The live ledger is the current evidence; reconcile the manifest in a separate documentation task before relying on its older status labels.

## 1. Method and safety boundary

- Read the repository tree at the baseline commit and inspected the migration inventory, archive inventory, migration recovery manifest, and selected SQL files.
- Queried PostgreSQL catalogs using SELECT-only statements against both project refs:
  - Production: `hwqtsopvpucadgpkigqz`
  - Staging: `cppalwtdkditlhojpeyc`
- Compared function identity/signature and `md5(pg_get_functiondef(...))`; trigger identity/definition/function binding; and RLS policy identity/definition.
- Catalog scope for counts: schemas `public`, `auth`, and `storage`. Internal PostgreSQL triggers (`tgisinternal`) were excluded from trigger counts.
- No application data tables were queried for user records. No functions were invoked. No secrets or environment variable values were read.
- Hash equality is a strong textual parity signal, not a proof of runtime behavior or semantic equivalence where hashes differ.

## 2. Live catalog parity

### 2.1 Functions

| Schema | Production | Staging | Difference |
|---|---:|---:|---:|
| public | 74 | 72 | +2 Production |
| auth | 4 | 4 | 0 |
| storage | 24 | 24 | 0 |
| **Total** | **102** | **100** | **+2 Production** |

Public function identity differences:
- Production only: `public.abandon_exam_attempt(uuid)`
- Production only: `public.save_exam_atomic(uuid, text, text, integer, jsonb, jsonb, boolean, uuid)`
- No Staging-only public function identity was returned.
- Same identity but different definition hash:
  - `public.bootstrap_first_admin()`
  - `public.handle_new_auth_user()`
  - `public.submit_exam_attempt(uuid)`

Interpretation:
- `bootstrap_first_admin()`: Production is pinned to the configured Production administrator identity; Staging is pinned to its test administrator identity. This is expected environment-specific configuration, but both remain privileged public RPCs and must not be copied blindly between environments.
- `handle_new_auth_user()`: Production requires a valid supplied display name; Staging includes a fallback for dashboard-created users with missing metadata. This is a behavioral difference, not merely formatting.
- `submit_exam_attempt(uuid)`: definition hash differs. The catalog output shows formatting/structure differences; a normalized AST or careful full-body semantic comparison and identical grading regression tests are still required before treating the implementations as equivalent.
- `abandon_exam_attempt` and `save_exam_atomic` are present only in Production catalog. Their absence from Staging must be explained by source/migration history and caller inventory before any retirement decision.

### 2.2 Triggers

| Schema | Production | Staging | Difference |
|---|---:|---:|---:|
| public | 34 | 33 | +1 Production |
| auth | 1 | 1 | 0 |
| storage | 11 | 11 | 0 |
| **Total** | **46** | **45** | **+1 Production** |

The only public trigger identity returned in Production but not Staging:

```sql
CREATE TRIGGER attempt_question_times_guard
BEFORE INSERT OR DELETE OR UPDATE ON attempt_question_times
FOR EACH ROW EXECUTE FUNCTION guard_attempt_child()
```

The `attempt_answers_guard` trigger exists in both environments and is bound to `public.guard_attempt_child()`. The `exam_versions_immutable_after_publish` trigger exists in both and is bound to `public.protect_exam_version()`.

**Risk:** the Production-only trigger means attempt timing writes are subject to an additional database guard not present in Staging. This is a real parity gap. Do not drop it from Production or add it to Staging as part of a read-only audit. First establish its intended behavior and test the timing write path in a controlled environment.

### 2.3 RLS policies

| Schema | Production | Staging | Parity |
|---|---:|---:|---|
| public | 42 | 42 | Exact key + definition-hash match |
| storage | 4 | 4 | Exact key + definition-hash match |
| **Total** | **46** | **46** | **Exact match** |

The 42 public policies and four Storage policies matched by schema/table/policy name and normalized policy definition hash in the catalog query. This confirms catalog parity for those policies only; it does not independently prove grants, table RLS flags, role membership, function EXECUTE privileges, or effective authorization behavior are identical.

## 3. Trigger and SQL dependency map

### 3.1 Attempt lifecycle and history

- `attempt_answers_guard` → `public.guard_attempt_child()` → reads `attempts` and `profiles`; enforces active owner and in-progress state for child-row mutations.
- Production-only `attempt_question_times_guard` → same `public.guard_attempt_child()`; extends the guard to timing rows in Production.
- `attempts_guard_update` → `public.guard_attempt_record()`; protects attempt record transitions and identity.
- `start_exam_attempt()`, `save_attempt_answer()`, `record_attempt_question_time_v2()`, `submit_exam_attempt()`, `get_my_attempt_state()`, `get_my_attempt_history()`, and `abandon_exam_attempt()` are part of the attempt lifecycle. Preserve their contracts and history semantics until a replacement passes start/resume, answer persistence, timing/offline replay, idempotent submit, grading, abandonment and history parity.
- `get_my_attempt_state()` has an internal call path to `submit_exam_attempt()` when timeout handling requires finalization (as identified in the preceding SQL call-graph audit).

### 3.2 Exam/version authoring and publication

- `exam_versions_immutable_after_publish` → `public.protect_exam_version()`; protects published version immutability and guarded archive behavior.
- `exam_version_questions_protected` → `public.protect_exam_version_questions()`; protects question mappings for published versions and guarded deletion flows.
- `exam_versions_education_publish_guard` → `public.education_exam_version_publish_guard()`; requires an active education-subject placement before publication.
- `exams_education_placement_guard` → `public.education_exam_placement_guard()`; protects placement validity and identity.
- Authoring wrapper chain identified in Phase 8 remains relevant: `admin_save_exam_content_with_education()` → `admin_save_exam_content_with_category()` → `admin_save_exam_content()` and `admin_set_exam_education_subject()`, with optional publication through `admin_publish_exam_version()`. Internal helpers must not be retired merely because they lack a JavaScript caller.

### 3.3 Identity, audit and taxonomy guards

- `on_auth_user_created_profile` → `public.handle_new_auth_user()` (auth.users insert).
- `audit_exam_changes` → `public.audit_exam_change()`.
- `audit_profile_changes` → `public.audit_profile_change()`.
- `prevent_last_active_admin` → `public.prevent_last_active_admin_removal()`.
- `prevent_last_admin_delete` → `public.prevent_last_admin_delete()`.
- `question_answer_keys_immutable` → `public.prevent_answer_key_change()`.
- `question_versions_immutable` → `public.prevent_question_version_change()`.
- `questions_identity_immutable` → `public.prevent_question_identity_change()`.
- Taxonomy and stimulus triggers call M1 validation/protection helpers; subject code and category hierarchy triggers call their respective guard/updated-at helpers.
- Education level/node/subject triggers call identity, active-path and updated-at helpers.

### 3.4 RLS helper classification

- `public.is_admin()` is a shared authorization helper referenced by the public policies and Storage policies. It is not a dead helper and cannot be retired while any policy, RPC, trigger, or other database object depends on it.
- `auth.uid()` and related `auth` helpers are platform authentication functions, not application-owned replacement candidates.
- Function-to-policy dependencies must be audited alongside function-to-trigger and function-to-function dependencies. A JavaScript caller search alone is insufficient.

### 3.5 Storage

- The 11 Storage triggers are Supabase-managed platform behavior; do not treat them as application legacy.
- Four Storage policies protect the `tsa-imports` bucket through `is_admin()`. Any Import replacement must preserve the required Storage authorization contract or intentionally replace it with a separately reviewed design.

## 4. Migration provenance findings and unresolved evidence

- Repository tree at baseline contains 30 active SQL migration files plus four files under `supabase/migration_archive/`.
- The archive includes an original-timestamp AI import migration and superseded drafts for exam-room timing and safe version deletion/archive.
- The recovery manifest records a 17-statement recovered fingerprint set and later migrations. Its historical labels for the seven education migrations say repository-only/Staging-only, but the live Production migration ledger currently lists all seven education migration versions as applied. Treat those manifest labels as stale until reconciled.
- The live Production migration ledger contains the original timestamp lineage for the pre-education migration set and includes the education migration versions through `20261114024035`.
- The Staging ledger includes a reconstructed baseline and remapped timestamps for the recovered legacy migration set, plus a Staging-specific display-name fallback migration. Its ledger lineage is therefore not byte-for-byte identical to Production even where current catalog objects match.
- Selected migration files examined define guard functions, but did not contain `CREATE TRIGGER` statements for the two guard attachments inspected. GitHub code search did not return matches for the exact trigger names. This does **not** prove no historical source exists: a full historical Git-object search, database bootstrap source review, and platform provisioning history remain outstanding.
- Provenance for `attempt_question_times_guard` is especially important because it exists only in Production. The source of its creation and intended Production-only status remain unverified.

## 5. Required follow-up before any retirement

1. Complete historical provenance recovery for every application trigger, including the Production-only timing guard; identify exact originating commit/file or document an explicit approved baseline.
2. Reconcile migration ledgers and update the migration recovery manifest based on verified live ledger evidence; do not rewrite migration history.
3. Perform semantic diff and behavior tests for the three differing public function definitions, especially `submit_exam_attempt(uuid)`.
4. Explain Production-only `abandon_exam_attempt` and `save_exam_atomic`; inspect database dependencies, grants, callers and telemetry before classification.
5. Compare table RLS-enabled flags, grants, function EXECUTE ACLs, role membership, constraints, indexes, sequences, views, event triggers and relevant extension versions between Production and Staging. The current parity comparison does not cover these.
6. Preserve all attempt, answer, timing, event, score, version and published-snapshot records. No destructive cleanup is authorized by this audit.
7. For each proposed retirement, provide replacement contract, complete source/caller/DB dependency proof, 14–30 days of telemetry, Admin/Student E2E evidence, Production parity, rollback plan, and separate explicit approval for the specific destructive action.

## 6. Phase 10 disposition

**No component is approved for retirement.** This audit found a Production/Staging trigger parity gap and function definition differences that must be resolved first. This report is documentation only; no application source, migration, schema, data, grant, RLS policy, secret, Edge Function or deployment was changed.
