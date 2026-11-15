# Phase 19 — Production ACL Remediation Execution Report

**Date:** 2026-11-15  
**Project:** Supabase Production `hwqtsopvpucadgpkigqz`  
**Database:** `postgres`  
**Executor:** `postgres`  
**Approval:** Explicit user approval received in the conversation on 2026-11-15 to execute the previously reviewed Phase 19 scope.

## 1. Backup gate

A fresh custom-format Production dump was created locally before execution:

- File: `tsa-production-pre-acl-20261115.dump`
- Size: 861,034 bytes
- Created: 2026-11-15 16:43 local time (UTC+07)
- PostgreSQL client: `pg_dump` / `pg_restore` 17.12
- Verification: `pg_restore --list` completed successfully.

This verifies archive readability and TOC listing; it is not a full isolated restore drill. The backup was created in the user's local `C:\Windows\system32` working directory and should be moved to a dedicated backup location after the operation.

## 2. Immediate pre-execution snapshot

The read-only Phase 18 snapshot query was run immediately before remediation at `2026-11-15T09:47:23.724384+00:00`.

- Snapshot fingerprint: `ba2117f754b9afa587e0c9324e615017`
- Database: `postgres`
- Server version: `17.11`
- Bootstrap function fingerprint: `af408493755e9b37e2e3365206d86f06`
- Staging bootstrap sentinel: `false`
- Target tables found: 12
- Target sequences found: 3
- All target objects remained owned by `postgres`.
- Raw target ACLs, column ACL, and default ACLs matched the reviewed Phase 18 baseline required by the Phase 19 preflight.

The snapshot fingerprint includes its capture timestamp; baseline comparison is based on the contained ACL and structural fields, not equality of the timestamp-dependent fingerprint with the earlier Phase 18 capture.

## 3. Execution

The Production-specific reviewed artifact `docs/architecture/drafts/phase-19-production-acl-remediation-draft.sql` was used as the source for a controlled in-memory execution copy.

Only these runtime transformations were made:
1. Removed the intentional design-only exception guard from the runtime copy.
2. Added transaction-local `lock_timeout = '5s'` and `statement_timeout = '90s'`.
3. Replaced the artifact's terminal `ROLLBACK` with `COMMIT` after all preflight and postflight assertions.

No repository SQL artifact was modified to remove its design guard. The transaction completed without a reported SQL error and committed.

## 4. Post-commit verification

An independent read-only query after commit returned:

| Check | Result |
|---|---:|
| `anon` has no effective privileges on 12 target tables | PASS |
| `authenticated` has SELECT only on `profiles` and `exams` | PASS |
| `authenticated` has no direct privileges on the other 10 target tables | PASS |
| `anon` and `authenticated` have no effective privileges on 3 target sequences | PASS |
| `profiles.display_name` UPDATE revoked for client roles | PASS |
| `service_role` retains all target table privileges | PASS (transactional postflight) |
| `service_role` retains USAGE/SELECT/UPDATE on all 3 sequences | PASS |
| `postgres` global and public sequence defaults no longer grant client roles | PASS |
| `supabase_admin` public sequence default ACL unchanged | PASS |
| Public RLS policies | 42 (unchanged) |
| Public non-internal triggers | 34 (unchanged) |
| Public RLS-enabled tables | 25 (unchanged) |
| Target table owners | 12/12 `postgres` |
| Target sequence owners | 3/3 `postgres` |
| Bootstrap function fingerprint | Unchanged |

The post-commit query also confirmed 74 public functions and 48 SECURITY DEFINER functions. Function ACLs and function bodies were outside the approved scope and were not modified.

## 5. Scope and exclusions

This execution changed only the approved direct table, column, sequence, and `postgres` sequence-default ACLs.

No application source, schema objects, table data, exam content, attempts, answers, scores, historical versions, sequence values, RLS policies, triggers, function ACLs, function bodies, Supabase platform defaults, or deployments were intentionally changed. No migration was created by the ACL execution.

The current migration ledger query returned 30 rows after execution. No pre-execution count was captured as part of this run, so this report does not claim a before/after ledger-count comparison.

## 6. Remaining verification

Database-level preflight and postflight passed. Production browser smoke/E2E validation is still required after the ACL change:

1. Logged-out visitor: public pages render and protected areas remain inaccessible.
2. Student: sign-in, catalogue loads, profile display, exam open, attempt start and submit.
3. Admin: sign-in, exam management, publishing, profile/admin workflows and reports.
4. Authorization boundary: Student cannot access Admin-only workflows.

The owner should perform these checks in the Production website and report the outcome. This report does not claim browser E2E completion.

## 7. Final status

**Database ACL transaction: COMMITTED.**  
**Database postflight: PASS.**  
**Production browser E2E: PENDING owner verification.**  
**PR #29: remains Draft and unmerged.**  
**Production deployment: unchanged.**


## 8. Production browser smoke test — owner-reported

On 2026-11-15, the owner reported all four requested Production smoke-test groups as passing:

1. Logged-out visitor: PASS (owner-reported).
2. Student sign-in, profile display, catalogue loading, and exam-room access: PASS (owner-reported; no real attempt/submit performed).
3. Admin sign-in and required administration screens: PASS (owner-reported; no content save or publication performed).
4. Student denial of Admin-only routes/workflows: PASS (owner-reported).

These are owner-reported results. No independent browser automation was executed by the assistant in this verification step.

## 9. Phase 19 closure

**Phase 19: COMPLETE**, subject to the evidence qualifications above. The approved Production ACL transaction committed, database postflight passed, and all four owner-reported Production smoke-test groups passed.

The separate full isolated backup-restore drill remains outstanding and is not represented as completed. PR #29 remains Draft/unmerged; no application deployment was performed as part of Phase 19.


## 10. Consolidated PR review and CI — 2026-11-15

The audit branch was compared with `main` after the Phase 19 report update:

- Base: `92856f1bc65cfa2a4c8a96ab17480a554dc64aba`
- Branch: `audit/phase-16-staging-acl-remediation-design-20261115`
- Ahead/behind: 67 / 0
- Changed files: 27
- Changed paths are limited to architecture documentation, guarded SQL review/evidence artifacts, JSON evidence and `supabase/migration-recovery-manifest.json`; no application source files or active migration files are in the compare result.

Latest commit CI/status:
- Vercel: success.
- Netlify deploy preview: success.
- Supabase clean-install compatibility: success; all 31 job steps completed successfully.
- Migration recovery integrity: success.
- React migration CI: success.
- Recovered migration chain smoke test: success.

PR #29 review metadata:
- No submitted reviews.
- No inline review threads.
- PR remains Draft and unmerged by design.

The live Production migration ledger was read-only checked after Phase 19 and contains 30 entries. The 30 versions/names match the repository migration recovery manifest's recovered and subsequent migration inventory. No migration was added by the ACL transaction.

## 11. Backup restore drill status and boundary

A full isolated restore drill has **not** been run. The custom-format archive is on the owner's Windows machine, currently under `C:\Windows\system32`; the assistant's connected GitHub/Supabase tools cannot read that local file. No backup containing Production data was uploaded to a third-party environment, and no paid Supabase branch/project was created.

To complete this final evidence gate, the owner must run the archive restore locally against a disposable PostgreSQL 17 instance (not Production or Staging), then verify restore completion and basic catalog/table counts. The dump should first be moved to a dedicated backup directory. This local restore test is the only remaining operational validation item before the consolidated audit package can be considered fully evidenced for approval.
