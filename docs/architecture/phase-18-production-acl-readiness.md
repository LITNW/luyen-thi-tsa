# Phase 18 — Production ACL Readiness Assessment

**Date:** 2026-11-15  
**Repository baseline:** `main` at `92856f1bc65cfa2a4c8a96ab17480a554dc64aba`  
**Production Supabase project:** `hwqtsopvpucadgpkigqz`  
**Staging Supabase project:** `cppalwtdkditlhojpeyc`  
**Mode:** Read-only Production catalog inspection, repository caller audit, and Production-specific SQL design. No Production mutation.

## 1. Executive result

Production is structurally suitable for a narrowly scoped table/column/sequence ACL rollout, subject to a fresh pre-rollout backup and final snapshot comparison. The Staging script must not be reused unchanged: Production has a different baseline and uses a different bootstrap identity.

The Production-specific preflight was executed inside `BEGIN ... ROLLBACK` and passed. It made no database changes. The Production remediation remains guarded and ends in `ROLLBACK`; it has not been executed.

**Readiness status: CONDITIONAL — NOT YET AUTHORIZED FOR EXECUTION.**

## 2. Environment and deployment identity

- Supabase Production status: `ACTIVE_HEALTHY`.
- PostgreSQL: `17.11.0.018`.
- Database name: `postgres`.
- SQL execution identity: `postgres`, `rolsuper=false`, can `SET ROLE postgres`.
- Production `bootstrap_first_admin()` definition fingerprint: `af408493755e9b37e2e3365206d86f06`.
- Staging bootstrap marker `staging-admin@example.test` is absent from the Production function.
- Production and Staging are in `ap-southeast-1`.

Cloudflare Pages project `luyen-thi-tsa` is configured with Production `VITE_SUPABASE_URL` pointing to Production ref `hwqtsopvpucadgpkigqz`, and Preview pointing to Staging ref `cppalwtdkditlhojpeyc`. The canonical Production deployment `7b030e02-f508-4942-a59d-904e1a86d84c` is successful on commit `92856f1bc65cfa2a4c8a96ab17480a554dc64aba`. The latest audit-branch Preview deployment was skipped by path configuration; it did not replace Production.

## 3. Production ACL baseline

Read-only snapshot captured at `2026-11-15T09:34:50.513232+00:00`, fingerprint `803d6fc3d3ab475ffaa700b5eb05bae5`. Snapshot is retained at `docs/architecture/evidence/phase-18-production-acl-snapshot-readonly-20261115.json`.

- All 12 target tables and all 3 target sequences exist and are owned by `postgres`.
- `anon` currently has no effective table privileges on the 12 target tables.
- `authenticated` currently has SELECT on 10 target tables: `attempt_answers`, `attempt_question_times`, `attempts`, `audit_logs`, `exam_version_questions`, `exam_versions`, `exams`, `profiles`, `question_versions`, and `questions`.
- Direct INSERT/UPDATE/DELETE grants to `authenticated` exist on `exam_version_questions`, `exam_versions`, `question_versions`, and `questions`.
- `exam_solutions` and `question_answer_keys` have no client-role table ACL entries.
- `authenticated` has column-level `UPDATE(display_name)` on `profiles`; `anon` does not.
- Both client roles have `SELECT`, `UPDATE`, and `USAGE` on all 3 target sequences.
- `postgres` global sequence default ACL has no override row; its `public` schema default grants sequence privileges to `anon`, `authenticated`, and `service_role`.
- `supabase_admin/public` sequence default ACL is the known platform-managed ACL and is excluded from changes.

The detailed snapshot JSON is authoritative; the exact raw ACL strings and per-object effective privileges are retained there.

## 4. Intended Production target

The target is deliberately limited to the Phase 16 rehearsed scope:
- `anon`: zero direct privileges on all 12 target tables and all 3 target sequences.
- `authenticated`: SELECT only on `public.profiles` and `public.exams`; no direct table privileges on the other ten tables.
- No `UPDATE(display_name)` for `anon` or `authenticated`.
- No client-role privileges on the three target sequences.
- Remove `anon` and `authenticated` from both global and `public` sequence default ACLs for creator `postgres`.
- Preserve object ownership, all `service_role` privileges, RLS policies, triggers, function bodies/ACLs, data, sequences' values, and `supabase_admin` defaults.

The target does not alter function EXECUTE grants. Phase 12's function ACL rehearsal was Staging-only; Production has a different function inventory and must be handled as a separate security workstream.

## 5. Client-call-site and dependency review

Current `main` source was inspected:
- Legacy client reads the signed-in user's `profiles` row.
- React Admin and legacy code read `exams` metadata.
- Admin account updates use `admin_update_profile` RPC, not direct profile writes.
- Admin exam/version/attempt/report workflows use RPCs.
- No direct frontend `.from()` call was found for the other ten target tables.
- Direct `education_subjects` and `import_questions` accesses exist outside this 12-table target and are not changed by this rollout.

The owner previously confirmed from project records that there are no external mobile apps, standalone scripts, third-party dashboards or services directly using these target tables/sequences through `anon` or `authenticated`. This is an owner-provided assurance, not independently proven by a complete external traffic inventory.

## 6. Production structural invariants

Read-only Production catalog results:
- Public application tables with RLS enabled: 25.
- Public RLS policies: 42.
- Non-internal public triggers: 34.
- Supabase-managed `supabase_admin`-owned public relations/functions: 0.
- Production has one known trigger beyond Staging's 33: `attempt_question_times_guard`, documented in Phase 10.
- Production public functions: 74; SECURITY DEFINER functions: 48.
- Security Advisor currently reports 41 authenticated-callable SECURITY DEFINER warnings, 3 informational RLS-enabled/no-policy findings, and 1 leaked-password-protection warning.

The Phase 19 preflight asserts the Production bootstrap fingerprint, exact ACL baseline for all 15 target objects, column ACL, both postgres sequence-default scopes, immutable platform default ACL, 25 RLS-enabled tables, 42 policies, 34 public non-internal triggers, object ownership, and executor authority.

The 41 SECURITY DEFINER warnings and other Advisor findings are existing issues outside this table/sequence ACL rollout. This phase does not revoke function EXECUTE privileges or claim those warnings are resolved.

## 7. Production-specific artifacts prepared

1. `docs/architecture/drafts/phase-18-production-acl-snapshot.sql` — SELECT-only snapshot including the Production bootstrap definition fingerprint.
2. `docs/architecture/evidence/phase-18-production-acl-snapshot-readonly-20261115.json` — captured Production baseline.
3. `docs/architecture/drafts/phase-19-production-acl-remediation-draft.sql` — Production-specific guarded draft. Includes exact raw-ACL baseline guards and Production structural invariants; design guard remains active and terminal statement is `ROLLBACK`.
4. `docs/architecture/drafts/phase-19-production-rollback-generator.sql` — SELECT-only generator adapted to Production identity.
5. `docs/architecture/drafts/phase-19-production-rollback-preflight.sql` — generated from the captured Production snapshot; contains 47 matching `SET ROLE postgres` / `RESET ROLE` pairs, no `supabase_admin` role switch, no platform default mutation and no `COMMIT`. It has not been executed.

The Production preflight DO block was tested in a transaction ending in `ROLLBACK`; it passed. No Production ACL, schema, data, sequence value, migration, secret or deployment was changed.

## 8. Backup and final execution gate

The previously verified Production custom-format dump was created on 2026-11-14 at 13:43, size 692,886 bytes. `pg_restore --list` read it successfully, but that was not a full restore drill and it predates this readiness assessment.

Before Phase 19 execution:
1. Create a fresh custom-format Production `pg_dump` after this readiness assessment and verify it with `pg_restore --list`.
2. Capture a fresh Production ACL snapshot immediately before execution and compare its object ACLs, column ACL, sequence ACLs and default ACLs against the reviewed baseline. If any drift exists, stop and regenerate the remediation and rollback artifacts.
3. Re-run the Production-specific preflight in a transaction ending in `ROLLBACK`.
4. Review the generated rollback and verify the execution identity can `SET ROLE postgres`.
5. Execute the guarded remediation in one bounded transaction with lock/statement timeouts; only replace the design guard and terminal `ROLLBACK` in the controlled runtime copy after all gates pass.
6. Verify postflight, then run Production smoke tests and monitor logs. Keep the rollback artifact available.

No migration is required for this ACL-only change, and the migration ledger must remain unchanged. No legacy retirement is included.

## 9. Decision

Phase 18 has completed the read-only Production readiness assessment and prepared Production-specific scripts. Production is **conditionally ready**, but the fresh backup and immediate pre-rollout snapshot gates remain outstanding. No Production rollout has occurred.


## 10. Consolidation review link
- The audit package is available as draft PR #29: https://github.com/LITNW/luyen-thi-tsa/pull/29.
- The PR is intentionally unmerged and contains 27 changed files. CI was still running at the time of this report update; Vercel status was successful and Netlify Preview was pending.
