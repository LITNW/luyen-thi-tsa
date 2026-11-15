# Phase 11 — Dependency Provenance Completion & Privilege Parity Audit

**Date:** 2026-11-15  
**Repository:** `LITNW/luyen-thi-tsa`  
**Database scope:** Production `hwqtsopvpucadgpkigqz`; Staging `cppalwtdkditlhojpeyc`  
**Repository baseline:** `main` at `92856f1bc65cfa2a4c8a96ab17480a554dc64aba`  
**Changes:** documentation and recovery-manifest metadata only, on a separate audit branch.

## Executive summary

- The exact source origin of the Production-only `attempt_question_times_guard`, `abandon_exam_attempt(uuid)`, and `save_exam_atomic(...)` could not be established from the accessible Git history, active migration files, archive, or live migration ledgers. A manual SQL Editor change is possible but **not proven**. Database catalogs do not record who/when created an object.
- The three function definitions with different raw hashes were semantically compared. `submit_exam_attempt(uuid)` has identical normalized body hash after removing comments and whitespace; this is strong evidence of formatting-only drift, not proof of behavioral parity. `bootstrap_first_admin()` differs only by environment-specific administrator email. `handle_new_auth_user()` has a real behavior difference: Staging supplies a fallback display name, Production rejects missing/blank names.
- RLS is enabled on all 25 public tables and all 10 Storage tables in both environments; FORCE RLS is false on all counted tables.
- Function privileges are materially different. Public functions with effective EXECUTE for anon: **18 Production vs 32 Staging**. For authenticated: **59 Production vs 68 Staging**. All 74/72 public functions are executable by service_role.
- Staging grants anon effective EXECUTE on several SECURITY DEFINER attempt functions that Production does not expose to anon. This is a high-priority security-parity finding. No grants were changed.
- Structural counts match: **166 constraints, 97 indexes, 0 public views, 0 materialized views** in each environment. Exact constraint/index definitions have not been fully diffed by this report; equal counts are not exact parity.
- Role membership relationships and admin_option values match across the two queried catalogs.
- Production and Staging migration ledgers were re-read. The seven Education migration entries are present in both. The recovery manifest was updated on this audit branch to record the verified live-ledger state, without modifying either database ledger.

## 1. Provenance recovery

### 1.1 Production-only trigger

`public.attempt_question_times.attempt_question_times_guard` exists in Production and not Staging. It is a BEFORE INSERT/UPDATE/DELETE guard invoking `public.guard_attempt_child()`.

Searches of:
- all tracked active migrations,
- `supabase/migration_archive/`,
- migration recovery manifest,
- GitHub code search for the trigger identifier,
- searchable Git commit metadata,

did not locate an originating `CREATE TRIGGER` statement or a commit that clearly introduced it.

**Disposition:** origin unresolved. A SQL Editor change, an omitted historical migration, a manual restoration, or an older branch remain hypotheses only. Do not select one as fact. Supabase's current catalog and migration ledger do not expose object creator/time provenance. Further evidence would require retained database/audit logs or a known historical dump/schema snapshot.

### 1.2 Production-only functions

- `public.abandon_exam_attempt(uuid)`: exists only in Production. Its body checks `auth.uid()`, locks the attempt row, verifies ownership and `in_progress` state, computes elapsed time, then marks the attempt abandoned. No originating migration or Git commit was found in the searched history.
- `public.save_exam_atomic(...)`: exists only in Production. It accepts an actor UUID, checks that actor's profile is active Admin, writes legacy `exams`/solutions and an audit log. It is SECURITY DEFINER and uses `search_path = public`. No originating migration or Git commit was found in the searched history. It is a potential legacy authoring path and must not be removed until all DB and external callers are accounted for.

The lack of a Git search result does not prove manual SQL Editor creation. Provenance remains unknown.

## 2. Semantic comparison of divergent function definitions

### `bootstrap_first_admin()`

- Both environments require an authenticated user, acquire the same advisory transaction lock, require a confirmed email, reject if an Admin already exists, and promote exactly one active student profile.
- Production is pinned to the Production administrator email; Staging is pinned to `staging-admin@example.test`.
- This is an intentional environment-specific identity parameter, not a candidate for literal cross-environment copying.
- Keep both protected; any future change must preserve one-time bootstrap and verified-email checks.

### `handle_new_auth_user()`

- Production requires a nonblank supplied `raw_user_meta_data.display_name` and rejects missing/blank values.
- Staging validates email first, then derives a fallback display name from the email local-part when metadata is missing.
- This is a genuine behavioral difference affecting sign-up and dashboard-created users.
- The trigger is attached to `auth.users`; do not replace this function without testing signup, dashboard-created users, duplicate profile handling, email updates and profile constraints in both environments.

### `submit_exam_attempt(uuid)`

- Raw catalog hashes differed.
- A second hash after stripping SQL comments and whitespace was identical in both environments: `84483e9fa47a838e29a8b70a65cfe1da`.
- This indicates the observed definition drift is formatting/comment-only under that normalization.
- It does not replace regression tests for every question type, partial DND scoring, missing answers, idempotent resubmission, elapsed-time capping, score persistence and result-history parity.

## 3. RLS-enabled table parity

| Schema | Production tables | RLS enabled | FORCE RLS | Staging tables | RLS enabled | FORCE RLS |
|---|---:|---:|---:|---:|---:|---:|
| public | 25 | 25 | 0 | 25 | 25 | 0 |
| storage | 10 | 10 | 0 | 10 | 10 | 0 |

RLS-enabled flags and counts match. FORCE RLS is not enabled on these tables in either environment. This is a catalog observation, not an assertion that all effective access paths are equivalent.

## 4. Function EXECUTE privileges and ACL parity

### 4.1 Effective privilege counts

| Public function metric | Production | Staging |
|---|---:|---:|
| Functions total | 74 | 72 |
| EXECUTE effective for anon | 18 | 32 |
| EXECUTE effective for authenticated | 59 | 68 |
| EXECUTE effective for service_role | 74 | 72 |
| SECURITY DEFINER functions | 48 | 46 |

Counts use PostgreSQL `has_function_privilege(role, function_oid, 'EXECUTE')`, so inherited PUBLIC privileges are included.

### 4.2 Critical ACL finding

Staging exposes additional functions to anon through the default PUBLIC EXECUTE ACL (catalog ACL entry `=X`). Among the anon-effective EXECUTE set, the following SECURITY DEFINER functions are present in Staging but not Production:

- `audit_exam_change()` and `audit_profile_change()` — trigger-returning functions; direct RPC invocation is not equivalent to trigger execution, but PUBLIC EXECUTE is unnecessary exposure.
- `handle_new_auth_user()` — trigger-returning function.
- `is_admin()` — SECURITY DEFINER authorization helper.
- `prevent_last_active_admin_removal()` and `prevent_last_admin_delete()` — trigger-returning guards.
- `record_attempt_question_time(...)` — SECURITY DEFINER, callable by anon in Staging; Production restricts it to authenticated/service_role.
- `save_attempt_answer(...)` — SECURITY DEFINER, callable by anon in Staging; Production restricts it to authenticated/service_role.
- `start_exam_attempt(...)` — SECURITY DEFINER, callable by anon in Staging; Production restricts it to authenticated/service_role.

Production's 18 anon-effective functions in this catalog query are non-SECURITY-DEFINER trigger/helper functions, including education/taxonomy/category guards and `set_updated_at()`. They remain unnecessary public EXECUTE grants but are not equivalent to exposing privileged SECURITY DEFINER attempt RPCs.

**Risk classification:** High for Staging's anon-effective SECURITY DEFINER attempt functions. Their bodies were not invoked in this audit. The existing ownership/auth checks may mitigate unauthorized data access, but relying only on function-body checks is not a substitute for least-privilege grants. No grant was revoked or modified.

### 4.3 Authenticated and service_role

Authenticated EXECUTE count is 59 Production vs 68 Staging. This reflects a separate ACL drift that needs a signature-by-signature allowlist review. The aggregate count alone does not prove which nine differences are safe or unsafe.

All public functions are executable by service_role in both catalogs. No service_role privilege change is proposed.

## 5. Constraints, indexes, views and role membership

| Object class | Production | Staging | Current conclusion |
|---|---:|---:|---|
| Constraints in public | 166 | 166 | Counts match; exact definition diff outstanding |
| Indexes in public | 97 | 97 | Counts match; exact definition diff outstanding |
| Views in public | 0 | 0 | Count match |
| Materialized views in public | 0 | 0 | Count match |

Role membership rows and `admin_option` values match across the queried catalogs (24 memberships). This comparison covers the memberships returned by `pg_auth_members`; it does not compare every role attribute, ownership, default privileges, schema/table/sequence ACLs or database-level grants.

## 6. Migration ledger reconciliation

Live Production ledger currently contains 29 entries, including all seven Education migrations:

- `20261113155228` education_hierarchy_foundation
- `20261113155356` education_hierarchy_active_profile_read_policies
- `20261113155742` education_hierarchy_identity_guards
- `20261113160130` education_exam_placement_and_scoped_catalogue
- `20261113160231` education_exam_placement_identity_guard
- `20261113161654` education_atomic_editor_save
- `20261114024035` education_exam_version_publish_guard

Live Staging ledger contains 32 entries, including the same seven Education versions. Staging also has a reconstructed baseline and a Staging-specific `staging_auth_profile_display_name_fallback` entry.

The recovery manifest had incorrectly labelled all seven Education migrations as repository-only/not applied to Production. On this audit branch only, those seven entries now state that they are present in both live ledgers, with verification date 2026-11-15. The old `recovery_snapshot_pending` label for `20261112050000` is explicitly marked as historical snapshot status, not current Production status.

**Important:** ledger presence is not proof that a particular live object was created by that migration or that object definitions are identical. The migration ledger itself was not changed.

## 7. Remaining work before retirement

1. Obtain retained audit/query logs or a historical schema dump to establish provenance for the Production-only trigger and functions. If unavailable, formally record provenance as unknown and retain the objects.
2. Run a full signature-level ACL diff and define an approved role allowlist for each exposed function. Review PUBLIC grants, anon, authenticated and service_role separately.
3. Review all SECURITY DEFINER functions for fixed search_path, authorization checks, data ownership checks and unnecessary public EXECUTE.
4. Complete exact constraint and index definition comparison; compare ownership, schema/table/sequence ACLs, default privileges, role attributes, extensions and event triggers.
5. Reconcile Production-only legacy authoring and attempt functions with all DB dependencies, Edge/cron/external clients and telemetry.
6. Preserve attempt, answer, timing, event, score, exam-version and published-snapshot data.
7. No retirement until replacement parity, 14–30 days telemetry, Admin/Student E2E, Production smoke/controlled verification, rollback and object-specific approval are complete.

## 8. Phase 11 disposition

**No object is approved for retirement.** The most important new blocker is the Staging anon EXECUTE exposure of SECURITY DEFINER attempt functions and the broader authenticated ACL drift. This phase made no database changes: no DDL/DML, grants, RLS, secrets, migrations, function invocation, deployment or data mutation. The only repository change is documentation/manifest reconciliation on this isolated audit branch.
