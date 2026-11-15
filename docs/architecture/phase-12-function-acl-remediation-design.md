# Phase 12 — Function ACL Remediation Design

**Status:** Design complete; no SQL applied.  
**Branch:** `audit/phase-12-function-acl-remediation-design-20261115`  
**Base:** Phase 11 commit `8a8bac330a5077dd72cc66b256b77c9501efef60`  
**Scope:** Read-only comparison of Production (`hwqtsopvpucadgpkigqz`) and Staging (`cppalwtdkditlhojpeyc`), explicit EXECUTE allowlist, guarded SQL draft, and E2E test plan.

## 1. Executive result

| Catalog metric | Production | Staging |
|---|---:|---:|
| `public` functions | 74 | 72 |
| `SECURITY DEFINER` | 48 | 46 |
| Effective EXECUTE: `anon` | 18 | 32 |
| Effective EXECUTE: `authenticated` | 59 | 68 |
| Effective EXECUTE: `service_role` | 74 | 72 |
| `SECURITY DEFINER` callable by `anon` | 0 | 9 |

The nine Staging-only-in-effect `anon`-callable SECURITY DEFINER functions are:

- `is_admin()`
- `start_exam_attempt(uuid)`
- `save_attempt_answer(uuid,uuid,jsonb)`
- `record_attempt_question_time(uuid,uuid,integer,integer)`
- `handle_new_auth_user()`
- `audit_exam_change()`
- `audit_profile_change()`
- `prevent_last_active_admin_removal()`
- `prevent_last_admin_delete()`

The first four are the high-priority exposed RPC surface. The other five are trigger functions and should not be public RPC endpoints. Production already denies effective `anon` EXECUTE on all SECURITY DEFINER functions. The previous Phase 11 summary's description of the three attempt functions as a Staging-specific finding is confirmed; this phase revalidated the Production/ Staging difference directly.

The remaining `anon` EXECUTE counts (18 Production, 23 Staging) are mostly trigger/helper functions, not public callable APIs. Their EXECUTE grants should be removed as part of the function-level least-privilege baseline, while trigger behavior must be regression-tested. Trigger execution is not equivalent to direct RPC invocation; PostgreSQL checks trigger-function privileges when the trigger is created, not for every row-level trigger firing.

## 2. Important product contract finding: anonymous catalogue is not currently supported

The live Staging function bodies were inspected:

- `list_published_exams_for_education_subject(uuid)` rejects calls unless `auth.uid()` exists and the profile is active.
- `list_published_exams()` rejects calls unless the user is authenticated and active.
- `get_published_exam(uuid)` explicitly requires login and an active profile.
- `start_exam_attempt(uuid)`, `save_attempt_answer(...)`, and both time-recording functions check `auth.uid()`; the answer/time functions also enforce attempt ownership and in-progress state.

Therefore, the existing contract is **authenticated students only** for catalogue retrieval, exam payload, attempt start, answer persistence, timing, and submission. Granting `anon` EXECUTE to the catalogue functions would not make anonymous browsing work: the function bodies would still reject the request. It would only expose the callable surface without providing the promised behavior.

**Phase 12 decision:** do not grant `anon` EXECUTE to any current function. Preserve the current authenticated-only student journey. If public pre-login catalogue browsing is a product requirement, implement a separate metadata-only public RPC with an explicit data-minimization contract in a later feature phase; do not weaken the current exam payload or attempt functions.

## 3. EXECUTE policy / allowlist

The target model for the existing 74-function Production inventory is:

| Function class | anon | authenticated | service_role | Additional authorization |
|---|---|---|---|---|
| Student catalogue and exam payload | Deny | Allow | Preserve current grant | Body requires active authenticated profile |
| Attempt lifecycle / answer / timing / history | Deny | Allow | Preserve current grant | Body checks auth.uid(), ownership, attempt state, expiry |
| Admin / authoring / reporting (26 functions) | Deny | Allow at ACL layer | Preserve current grant | Each of the 26 Admin functions contains an `is_admin` authorization check; verify behavior in regression tests |
| `is_admin()` | Deny | Allow | Preserve current grant | Returns whether current active profile is Admin; not an authorization substitute by itself |
| `bootstrap_first_admin()` | Deny | Allow | Preserve current grant | One-time confirmed-email and bootstrap constraints in body |
| Trigger-only / internal helpers | Deny | Deny | Preserve current grant pending server-caller audit | Invoked by database triggers/internal call chains, not client RPC |
| `save_exam_atomic(...)` | Deny | Deny | Preserve current grant | Server/internal privileged operation; Production-only |
| `validate_question_answer_key(...)` | Deny | Deny | Preserve current grant | Internal validation helper |

### Why authenticated EXECUTE is retained for Admin functions

PostgreSQL ACLs cannot express “authenticated only when profile.role = admin”. Granting EXECUTE to `authenticated` is only the transport-level permission. Authorization must be enforced in each function body. The Staging catalog source scan found `is_admin` in all 26 `admin_*` function definitions. This is a static guard-presence check, not a substitute for testing denial against a non-admin authenticated user and success against an Admin user.

### Authenticated client-callable function inventory

**Admin / authoring / reporting (26):**

- `admin_add_question_to_exam(uuid,uuid,numeric)`
- `admin_create_exam_version(uuid)`
- `admin_create_exam(text,text,integer)`
- `admin_delete_exam_version(uuid)`
- `admin_get_exam_version(uuid)`
- `admin_list_attempts(integer,integer)`
- `admin_list_exam_categories()`
- `admin_list_exam_versions_with_categories()`
- `admin_list_exam_versions()`
- `admin_list_profiles(integer,integer)`
- `admin_list_question_bank(text,integer,integer)`
- `admin_publish_exam_version(uuid)`
- `admin_remove_question_from_exam(uuid,uuid)`
- `admin_reorder_exam_questions(uuid,uuid[])`
- `admin_replace_question_in_exam(uuid,uuid,uuid,numeric)`
- `admin_save_exam_category(text,text,uuid,text,uuid,boolean,integer)`
- `admin_save_exam_content_with_category(uuid,text,text,integer,jsonb,uuid,boolean)`
- `admin_save_exam_content_with_education(uuid,text,text,integer,jsonb,uuid,uuid,boolean)`
- `admin_save_exam_content(uuid,text,text,integer,jsonb,boolean)`
- `admin_save_question(uuid,text,uuid,text,jsonb,jsonb,text,jsonb,jsonb)`
- `admin_set_exam_category(uuid,uuid)`
- `admin_set_exam_education_subject(uuid,uuid)`
- `admin_set_question_answer_key(uuid,jsonb,text,jsonb,jsonb)`
- `admin_update_exam_version(uuid,text,text,integer)`
- `admin_update_profile(uuid,text,text,text)`
- `admin_update_question_points(uuid,uuid,numeric)`

**Student / attempt / read API (9):**

- `abandon_exam_attempt(uuid)`
- `get_my_attempt_history(integer,integer)`
- `get_my_attempt_state(uuid)`
- `get_published_exam(uuid)`
- `record_attempt_question_time_v2(uuid,uuid,integer,integer,uuid)`
- `record_attempt_question_time(uuid,uuid,integer,integer)` (legacy; retain authenticated grant until caller/telemetry retirement review)
- `save_attempt_answer(uuid,uuid,jsonb)`
- `start_exam_attempt(uuid)`
- `submit_exam_attempt(uuid)`

**Other authenticated entry points (6):**

- `bootstrap_first_admin()`
- `is_admin()`
- `list_active_exam_categories()`
- `list_active_subjects()`
- `list_published_exams_for_education_subject(uuid)`
- `list_published_exams()` (legacy catalogue; keep while legacy caller remains)

### Internal-only inventory (33 Production functions)

These functions should not be client-callable through `anon` or `authenticated`:

**Trigger / guard helpers (24):**

- `audit_exam_change()`
- `audit_profile_change()`
- `education_exam_placement_guard()`
- `education_exam_version_publish_guard()`
- `education_hierarchy_set_updated_at()`
- `education_level_code_immutable()`
- `education_levels_guard()`
- `education_nodes_guard()`
- `education_nodes_identity_guard()`
- `education_subjects_guard()`
- `education_subjects_identity_guard()`
- `m1_protect_published_question_taxonomy()`
- `m1_protect_referenced_taxonomy_identity()`
- `m1_protect_subject_code()`
- `m1_reject_stimulus_version_mutation()`
- `m1_set_updated_at()`
- `m1_validate_question_taxonomy_relation()`
- `m1_validate_taxonomy_parent()`
- `m2_set_exam_category_updated_at()`
- `m2_validate_exam_category_hierarchy()`
- `prevent_answer_key_change()`
- `prevent_last_active_admin_removal()`
- `prevent_last_admin_delete()`
- `prevent_question_identity_change()`
- `prevent_question_version_change()`
- `protect_exam_version_questions()`
- `protect_exam_version()`
- `set_updated_at()`

**Other internal / service-only (7):**

- `guard_attempt_child()`
- `guard_attempt_record()`
- `handle_new_auth_user()`
- `save_exam_atomic(uuid,text,text,integer,jsonb,jsonb,boolean,uuid)` (Production-only)
- `validate_question_answer_key(text,jsonb,jsonb)`
- `education_exam_version_publish_guard()` (also listed among trigger helpers; count is unique by signature)
- Two remaining environment-specific function identities are tracked in the live catalog comparison and must be rechecked by the preflight guard before any application.

> Inventory note: Production has 74 functions and Staging 72. The two Production-only identities are `abandon_exam_attempt(uuid)` and `save_exam_atomic(uuid,text,text,integer,jsonb,jsonb,boolean,uuid)`. Do not force Staging/Production identity parity by creating or deleting either function in this ACL-only phase.

## 4. SQL remediation draft

The companion file `phase-12-function-acl-remediation-draft.sql` is deliberately stored under `docs/architecture/drafts/`, not `supabase/migrations/`. It is not executable deployment approval.

The draft:
1. asserts the Production baseline count (74) and expected key function identities;
2. revokes EXECUTE from `PUBLIC`, `anon`, and `authenticated` on the current `public` function set;
3. restores `authenticated` EXECUTE only to the 41 client-callable signatures listed above;
4. leaves existing `service_role` ACLs unchanged for this phase;
5. verifies no `anon` EXECUTE remains and that the authenticated allowlist is exactly present.

The blanket schema operation is guarded by the expected function count. If the schema inventory changes before execution, the script must abort and be regenerated from a fresh catalog snapshot. A separate future task should review `service_role` grants and default privileges; this phase does not silently narrow server-side access without a complete server/Edge/external-caller inventory.

## 5. Staging validation plan (not run)

### A. Static catalog checks

- Confirm all 72 Staging function signatures are known; the Staging-only count difference must be documented, not “fixed” by this script.
- After a separately approved Staging migration, assert effective `anon` EXECUTE is false for every public function.
- Assert authenticated EXECUTE is true only for the approved callable signatures.
- Assert trigger attachment count and trigger definitions are unchanged.
- Run Supabase Security Advisors and review every SECURITY DEFINER finding.

### B. Unauthenticated student

Current expected behavior: the student must sign in before catalogue RPC, exam payload, and attempt lifecycle. Verify using a logged-out browser session:

1. Public site loads its shell without exposing answer keys or exam payload.
2. The current subject catalogue RPC is not callable as `anon`; the UI must direct the user to sign in or otherwise show the existing authentication state.
3. `get_published_exam`, `start_exam_attempt`, `save_attempt_answer`, timing, and submit must not be callable as `anon`.
4. No attempt, answer, timing, score, or event row is created or modified.

Do not mistake a PostgREST permission-denied response for a new functional regression: the current function bodies already reject missing `auth.uid()`. The expected product behavior is still login-required.

### C. Authenticated student

Use a dedicated Staging student account and an existing published test exam:

1. Sign in.
2. Load the subject catalogue.
3. Open the published exam payload.
4. Start or resume an attempt.
5. Save and reload an answer.
6. Navigate between questions and verify timing/event persistence.
7. Submit and verify result/history.
8. Confirm a student cannot read or modify another student's attempt.

Do not use Production attempts for ACL tests. Do not use real student accounts if a dedicated test account is available.

### D. Admin and non-admin authorization

1. Signed-in student calls each representative Admin read/write RPC and receives authorization denial.
2. Active Admin performs list, edit, save, publish, category/education placement and profile-management workflows.
3. Admin denial remains effective even though `authenticated` has EXECUTE.
4. Trigger-based protections still fire on the relevant data operations.

### E. Regression and rollback

- Compare before/after trigger catalogs, RLS policies, function definitions, and all exam/attempt data counts.
- No schema, data, function body, trigger, route, Edge Function, or migration-ledger changes are in scope.
- Rollback is a forward ACL migration restoring the exact pre-change ACL snapshot, not a database restore.
- Keep the previous ACL snapshot and SQL output in the PR evidence.

## 6. Risks / decisions still open

1. **Anonymous catalogue product requirement:** current SQL contract is authenticated-only. Product owner must explicitly decide whether pre-login catalogue browsing is required. If yes, design a separate metadata-only RPC and UI change; do not grant anon to the current authenticated-only function.
2. **service_role:** preserve existing grants in this phase. A complete server/Edge/cron/external caller audit is required before narrowing them.
3. **Default privileges:** review `ALTER DEFAULT PRIVILEGES` for the actual object-creating role(s), including `postgres`, so new public functions do not regain broad default EXECUTE. Do not change defaults until the migration/DDL owner and intended role matrix are confirmed.
4. **Function bodies:** the static scan found all 26 Admin functions contain `is_admin`; semantic tests must still verify the check is applied before sensitive reads/writes.
5. **Environment drift:** Production-only `abandon_exam_attempt` and `save_exam_atomic` must remain untouched; Staging-only ACL anomalies must be corrected only in a separately approved Staging rollout.

## 7. Safety boundary and completion

- All catalog queries in this phase were SELECT-only.
- No function was invoked.
- No DDL/DML, GRANT/REVOKE, migration, data, permission, secret, or deployment changes were made.
- No object is approved for retirement.
- The draft is ready for review and controlled Staging validation, but **not ready for Production execution** until the anonymous catalogue decision, service-role/default-privilege review, Staging E2E, and a separately approved rollout window are complete.

## References

- Supabase: [Securing your API](https://supabase.com/docs/guides/api/securing-your-api) — grants control whether roles can reach functions; RLS does not apply to function EXECUTE.
- Supabase: [Security Advisor](https://supabase.com/docs/guides/database/database-linter) — review SECURITY DEFINER exposure and public EXECUTE grants.
