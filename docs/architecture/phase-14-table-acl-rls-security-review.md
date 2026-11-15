# Phase 14 — Table ACL & RLS Security Review

**Date:** 2026-11-15  
**Mode:** Read-only review; no ACL remediation executed  
**Production:** `hwqtsopvpucadgpkigqz`  
**Staging:** `cppalwtdkditlhojpeyc`  
**Branch:** `audit/phase-14-table-acl-rls-review-20261115`

## 1. Executive summary

Phase 14 began with a detailed privilege matrix for the 12 public tables identified in Phase 13. The review compared effective table privileges, raw ACLs, RLS flags/policies, the Phase 12 Staging function allowlist, and current frontend call sites.

**Key findings:**

1. Staging grants both `anon` and `authenticated` all seven table privileges on all 12 tables: SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES and TRIGGER.
2. Production is narrower, but it is not a correct target by itself: four tables still grant authenticated CRUD, and six grant authenticated SELECT, even though the current application source scan found no direct client table calls for most of them.
3. All 12 tables have RLS enabled in both environments; none has FORCE ROW LEVEL SECURITY. The 23 policies are identical between environments (same normalized fingerprint). Policies target authenticated, not anon. `exam_solutions` and `question_answer_keys` have no policies in either environment, so ordinary RLS-governed access is default-deny for client roles.
4. RLS does not constrain TRUNCATE. The Staging TRUNCATE grants are unnecessary privilege surface. Standard PostgREST CRUD endpoints do not expose a TRUNCATE operation, so the catalog grant alone does not prove a currently exploitable REST endpoint. It must nevertheless be removed from client roles in a controlled remediation.
5. Source scan of the current `main` frontend found direct client table access among these 12 only for:
   - `profiles`: SELECT current user's profile in `public/legacy/index.html`.
   - `exams`: SELECT exam ID/education placement metadata in `src/pages/AdminPages.jsx` and `public/legacy/index.html`.
   No direct client `.from()` access was found for the other ten tables. Admin writes, exam authoring, exam attempts, answers, timing, history and results use RPCs.
6. All 40 Staging Phase 12 allowlisted functions are owned by `postgres`, are SECURITY DEFINER, have an empty pinned search_path, and are executable by authenticated but not anon. This is consistent with RPC-mediated access: those functions run with owner privileges, so client table grants are not required merely to call them. The function bodies remain the authorization boundary and must retain their auth/ownership/Admin checks.

**Preliminary least-privilege target for the 12-table scope:**
- `anon`: no table privileges on all 12 tables.
- `authenticated`: SELECT only on `profiles` and `exams`, because current code directly queries them.
- `authenticated`: no direct table privileges on the other ten tables; continue using the approved RPC layer.
- No client-role TRUNCATE, REFERENCES or TRIGGER on any of the 12 tables.

This is a remediation design recommendation, not an executed change or final migration approval.

## 2. Effective table privilege matrix

Legend: S=SELECT, I=INSERT, U=UPDATE, D=DELETE, T=TRUNCATE, R=REFERENCES, G=TRIGGER. `—` means no effective privilege. Production and Staging values below are effective privileges, not merely raw ACL text.

| Table | Production anon | Production authenticated | Staging anon | Staging authenticated | RLS policies |
|---|---|---|---|---|---|
| `attempt_answers` | — | S | SIUDTRG | SIUDTRG | Owner/Admin SELECT |
| `attempt_question_times` | — | S | SIUDTRG | SIUDTRG | Owner/Admin SELECT |
| `attempts` | — | S | SIUDTRG | SIUDTRG | Own/Admin SELECT |
| `audit_logs` | — | S | SIUDTRG | SIUDTRG | Admin SELECT |
| `exam_solutions` | — | — | SIUDTRG | SIUDTRG | No policy |
| `exam_version_questions` | — | SIUD | SIUDTRG | SIUDTRG | Published/Admin SELECT; Admin writes |
| `exam_versions` | — | SIUD | SIUDTRG | SIUDTRG | Published/Admin SELECT; Admin writes |
| `exams` | — | S | SIUDTRG | SIUDTRG | Published/Admin SELECT |
| `profiles` | — | S | SIUDTRG | SIUDTRG | Self/Admin SELECT and UPDATE |
| `question_answer_keys` | — | — | SIUDTRG | SIUDTRG | No policy |
| `question_versions` | — | SIUD | SIUDTRG | SIUDTRG | Published/Admin SELECT; Admin writes |
| `questions` | — | SIUD | SIUDTRG | SIUDTRG | Admin-only operations |

**Important:** Production is not adopted as the desired end state. The four Production CRUD grants (`exam_version_questions`, `exam_versions`, `question_versions`, `questions`) and the six Production SELECT grants must be assessed against real call sites. Least privilege is based on the application contract, not parity with an existing environment.

## 3. RLS posture

Both environments report:
- RLS enabled on all 12 tables.
- FORCE RLS enabled on none of the 12 tables.
- 23 policies across the scope.
- No policy targets `anon`.
- `exam_solutions` and `question_answer_keys` have no policies; with RLS enabled, ordinary client-role SELECT/INSERT/UPDATE/DELETE is default-deny unless another policy is introduced.
- Policy fingerprint matches exactly: `b77010745d38c7d0148712121b4c2fdd`.

Representative policy contracts:
- `attempts`: SELECT only for the owning user or Admin.
- `attempt_answers`, `attempt_question_times`: SELECT only where the parent attempt belongs to the current user or caller is Admin.
- `audit_logs`: Admin-only SELECT.
- `exams`: SELECT for published exams or Admin.
- `profiles`: SELECT and UPDATE constrained to own profile or Admin.
- `exam_versions`, `exam_version_questions`, `question_versions`: published content can be read; authoring writes require Admin.
- `questions`: Admin-only policies.

RLS is defense in depth, not a replacement for table ACLs. In particular:
- RLS does not apply to TRUNCATE.
- Table owners and BYPASSRLS roles can bypass RLS unless FORCE RLS applies; application client roles are not the table owner.
- A policy that permits a row does not make unnecessary INSERT/UPDATE/DELETE grants desirable.
- No anon policy exists, but anon still has unnecessary raw/effective table privileges in Staging.

## 4. Direct client Data API call-site inventory

The current repository `main` source was scanned for Supabase `.from()` and `.rpc()` calls across React pages, components/context and the legacy client.

| Table | Direct client use found | Operation | Current application purpose | Recommended authenticated table ACL |
|---|---|---|---|---|
| `profiles` | Yes — `public/legacy/index.html` | SELECT | Load the signed-in user's own profile | SELECT only |
| `exams` | Yes — `src/pages/AdminPages.jsx`, `public/legacy/index.html` | SELECT | Read exam ID and education placement metadata for Admin/category/editor flows | SELECT only |
| `attempts` | No | RPC | History/state/reporting through controlled functions | None |
| `attempt_answers` | No | RPC | Answer persistence and attempt-state retrieval | None |
| `attempt_question_times` | No | RPC | Timing persistence and state retrieval | None |
| `audit_logs` | No | RPC/internal | Audit logging and controlled reporting | None |
| `exam_solutions` | No | No direct client caller found | Internal/legacy solution data | None |
| `exam_version_questions` | No | RPC | Exam composition and publishing | None |
| `exam_versions` | No | RPC | Version list/editor/publish and published exam retrieval | None |
| `question_answer_keys` | No | RPC/internal | Answer-key validation, scoring and authoring | None |
| `question_versions` | No | RPC | Question content/version and scoring | None |
| `questions` | No | RPC | Question bank and authoring | None |

The legacy client uses RPCs for exam listing, exam payload, attempt state, answer save, timing, submit, result/history, Admin version listing and authoring. Direct `profiles` SELECT is filtered by the current user's ID. Direct `exams` SELECT is metadata-only in the inspected call sites.

This is a static source scan, not proof that no external integration or unpublished client exists. Before applying ACL changes, check external clients, scripts, dashboards and any browser extensions/integrations that may query these tables directly.

## 5. Phase 12 function allowlist cross-check

A fresh Staging catalog query matched all 40 Phase 12 allowlisted function identities:
- 40/40 owned by `postgres`.
- 40/40 SECURITY DEFINER.
- 40/40 have `search_path=""` configured.
- 40/40 effective EXECUTE for `authenticated`.
- 0/40 effective EXECUTE for `anon`.

The Phase 12 design identifies 26 Admin/authoring/reporting functions and 8 Student/attempt functions plus 6 catalogue/read/bootstrap entry points. Static body inspection previously confirmed the Admin allowlist contains `is_admin()` authorization checks and the Student functions check authenticated user context/ownership as appropriate.

The target-table reference scan is a textual scan of function definitions, not a PostgreSQL semantic dependency graph. Wrapper functions may call other functions and therefore may not mention underlying table names directly. The known save-content call chain must remain part of the review:
`admin_save_exam_content_with_education` → `admin_save_exam_content_with_category` → `admin_save_exam_content` and internal question/version save routines.

**Security implication:** because these allowlisted functions execute as the postgres owner, they do not need the calling client role to hold direct table privileges for the function's internal SQL. The client role needs EXECUTE on the approved RPC; the function body must enforce caller authorization and validate inputs/ownership. Do not grant broad table rights to make an RPC work.

## 6. Preliminary least-privilege target matrix

| Table group | anon | authenticated | Access path |
|---|---|---|---|
| `profiles` | No privileges | SELECT only | Direct self-profile read; profile changes through Admin RPC |
| `exams` | No privileges | SELECT only | Direct metadata read; changes through Admin RPC |
| `attempts`, `attempt_answers`, `attempt_question_times` | No privileges | No direct table privileges | Student/Admin RPCs with ownership/Admin checks |
| `audit_logs` | No privileges | No direct table privileges | Internal triggers and controlled Admin RPCs |
| `exam_solutions`, `question_answer_keys` | No privileges | No direct table privileges | Internal/RPC-only; retain RLS default-deny |
| `exam_version_questions`, `exam_versions`, `question_versions`, `questions` | No privileges | No direct table privileges | Admin authoring and Student published-exam RPCs |

For all 12 tables, client roles should not hold TRUNCATE, REFERENCES or TRIGGER. The target does not remove or alter grants for `service_role`, `postgres`, or platform roles.

## 7. Remediation design constraints

No SQL remediation or rollback script was executed or committed as executable migration. Before preparing the Staging rehearsal scripts:
1. Verify external callers and confirm that the two direct SELECT call sites are the only client table access paths.
2. Re-check all 12 raw ACLs, effective privileges, column-level ACLs and sequence dependencies.
3. Review every SECURITY DEFINER function body for authorization before sensitive reads/writes, fixed search_path, fully qualified objects, dynamic SQL and input validation.
4. Capture a full per-table/per-role rollback snapshot including grants, grant options, column ACLs and any relevant default privileges.
5. Design an idempotent, preflight-guarded transaction that changes only the 12 named tables and only anon/authenticated grants.
6. Verify post-state effective privileges, RLS policies, trigger catalog and table/attempt counts.
7. Run logged-out, Student, Admin and non-admin E2E, including all attempt workflows, editor/import flows and profile/education screens.
8. Preserve Staging rollback readiness; do not apply the script to Production or merge the audit branch without separate approval.

Potential rollout concern: a table-level REVOKE on `exams` or `profiles` would break the two identified direct SELECT call sites unless the authenticated SELECT grant is retained or those call sites are first migrated to approved RPCs. The proposed target retains SELECT for these two tables.

## 8. Phase 14 status and safety

**Completed:** initial Table Privilege Matrix, RLS policy comparison, source call-site scan, and Phase 12 allowlist cross-check.

**Not yet completed:** external caller confirmation, exhaustive per-signature SECURITY DEFINER semantic review, column-level ACL/sequence dependency audit, remediation/rollback script, Staging execution, E2E after table ACL changes.

No DDL, DML, GRANT, REVOKE, migration, extension change, data change, secret change, or deployment was performed in Production or Staging. No attempt, answer, score, timing, event, exam version or question data was modified.

**Decision:** the matrix supports a least-privilege design of no anon grants on all 12 tables and authenticated SELECT-only on `profiles` and `exams`, with no direct client privileges on the other ten. This is ready for technical review; it is not yet authorization to execute remediation.
