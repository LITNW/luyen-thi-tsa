# Phase 16 — Staging Table & Sequence ACL Remediation Design

**Status:** Design only. No SQL in this phase has been executed against Staging or Production.  
**Base:** Phase 14 audit branch `audit/phase-14-table-acl-rls-review-20261115`.  
**Target for a future rehearsal:** Supabase Staging project ref `cppalwtdkditlhojpeyc`.  
**Production:** Explicitly out of scope.

## 1. Objective and guardrails

Design a reversible, fail-closed ACL change for the 12 public application tables, the one known column-level grant, three public sequences, and sequence default privileges for object creators `postgres` and `supabase_admin`.

This branch contains review artifacts only. The SQL files are deliberately guarded with an initial exception and are **not executable remediation scripts** until a later phase removes the guard after external-caller clearance and independent review.

No migrations, application source, schema, data, function bodies, RLS policies, Storage ACLs, service-role grants, or deployments are changed.

## 2. Target state

### 2.1 Table ACL

For all 12 tables, remove direct table privileges from `anon` and `authenticated`:

- `attempt_answers`
- `attempt_question_times`
- `attempts`
- `audit_logs`
- `exam_solutions`
- `exam_version_questions`
- `exam_versions`
- `exams`
- `profiles`
- `question_answer_keys`
- `question_versions`
- `questions`

Then grant only `SELECT` to `authenticated` on `public.profiles` and `public.exams`. `anon` receives no direct table privileges.

The preflight must fail if an unexpected `PUBLIC` grant is found. This design does not silently revoke `PUBLIC` privileges because doing so would affect every role, including roles outside the two client roles.

### 2.2 Column ACL

Explicitly revoke `UPDATE (display_name)` on `public.profiles` from `anon` and `authenticated`. Verify the effective column privilege after table-level changes. PostgreSQL column grants are distinct ACL entries and must be inspected separately.

### 2.3 Sequence ACL

Remove all direct sequence privileges from `anon` and `authenticated` on:

- `public.audit_logs_id_seq`
- `public.import_events_id_seq`
- `public.tsa_user_code_seq`

The sequence grants are not needed merely because a SECURITY DEFINER routine writes a row with a sequence-backed default: the routine executes with its owner's privileges. This assumption must still be validated against the full trigger/function dependency chain before rehearsal.

### 2.4 Default sequence privileges

For both `postgres` and `supabase_admin`, inspect and remove client-role grants at both scopes:

- Global default ACL (no `IN SCHEMA` clause).
- Schema-specific default ACL for `public`.

Both scopes matter. PostgreSQL combines schema-specific defaults with global defaults; a schema-specific REVOKE cannot cancel a grant originating globally. Therefore the remediation must revoke at both scopes and postflight both catalog entries. See PostgreSQL 17 documentation:
- https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html
- https://www.postgresql.org/docs/17/sql-grant.html

The script must fail closed if the executing principal cannot alter defaults for either owner. Do not attempt to work around missing role membership by changing ownership or granting elevated membership.

## 3. Artifact inventory

| File | Purpose | Executes changes? |
|---|---|---|
| `phase-16-acl-snapshot.sql` | Read-only JSON snapshot of table, column, sequence and default ACL metadata | No |
| `phase-16-staging-acl-remediation-draft.sql` | Preflight, target statements and postflight assertions | Guarded; no |
| `phase-16-rollback-generator.sql` | Converts exported snapshot JSON into reviewable rollback SQL text | No; outputs text only |
| This report | Design, safety model, acceptance criteria and outstanding blockers | No |

The snapshot is an export artifact. Save its complete JSON result outside the SQL editor before any future change. The rollback generator consumes that exact exported JSON and emits statements; those statements must be reviewed and saved as a separate rollback file before remediation is considered.

## 4. Snapshot and rollback model

The snapshot captures:
- Database name, server version, Staging sentinel check and audit timestamp.
- Exact target table inventory, owner and ACL entries including grantor, grantee, privilege and grant-option flag.
- Explicit column ACL entries for `profiles.display_name`.
- Exact sequence inventory, owner and ACL entries.
- Global and `public` default ACL rows for `postgres` and `supabase_admin`, including whether a catalog override row exists and each ACL entry.

Rollback is generated only for the client-role ACLs this remediation changes. It first removes the current client-role grants on the target objects/defaults, then replays the original privileges and grant options from the snapshot. The generator emits `SET ROLE <original grantor>` around each GRANT so the recorded grantor can be restored when the executor is permitted to assume that role.

**Important limitation:** exact grantor restoration depends on the current operator being able to `SET ROLE` to each captured grantor. The rollback generator must fail/flag any grantor that cannot be assumed. It must not silently emit a different grantor and claim byte-for-byte ACL provenance. Owners' implicit privileges are not reconstructed as explicit grants.

The snapshot and generated rollback SQL must be retained together and checksummed before a future rehearsal. Do not rely on a manually reconstructed rollback from the report's summary tables.

## 5. Preflight assertions

The remediation draft must abort unless all conditions hold:

1. Connected database is `postgres`.
2. Staging-specific bootstrap sentinel is present: `bootstrap_first_admin()` contains `staging-admin@example.test`. This is an additional environment fingerprint, not a substitute for checking the Supabase project ref in the dashboard/connection metadata.
3. Exactly 12 expected target tables exist in `public`.
4. Exactly the three expected target sequences exist in `public`.
5. `profiles.display_name` exists.
6. Roles `anon`, `authenticated`, `postgres`, and `supabase_admin` exist.
7. No unreviewed `PUBLIC` ACL grants exist on the target tables, target column, sequences or relevant default ACLs.
8. The executor can alter default privileges for both specified owners; otherwise abort before any change.
9. Current ACLs match the snapshot reviewed immediately before execution. A changed baseline requires a new snapshot and review.

A project-ref check must be performed by the operator against the Supabase dashboard before execution. The database name alone is not unique to a Supabase project.

## 6. Transaction and postflight model

Future rehearsal must run as one transaction, with explicit lock and a short execution window. It must not include data changes.

Postflight assertions:
- `anon` has no effective table privilege on any of the 12 tables.
- `authenticated` has only effective `SELECT` on `profiles` and `exams`; no other table privilege on any target.
- Neither client role has effective `UPDATE` on `profiles.display_name`.
- Neither client role has effective `USAGE`, `SELECT`, or `UPDATE` on the three sequences.
- Neither client role appears in the global or public sequence default ACLs for either owner.
- No service-role ACL, owner, RLS policy, trigger, function definition, sequence value, table data or migration ledger entry changed.

If any postflight assertion fails, raise an exception so the transaction aborts. Do not commit partial remediation.

## 7. External-caller gate — still open

Phase 15 found direct client calls in the checked repository to `profiles` and `exams`, but could not prove that no external client, script, dashboard, integration or older deployment uses direct access to the other tables or sequences.

Before a Staging rehearsal, obtain explicit confirmation that:
- No external application or script uses direct Data API access to the 12 tables or three sequences.
- Any operational/admin scripts use a privileged backend role rather than client-role ACLs.
- The import workflow's deployed Edge Function status and its actual database role have been confirmed. Source code exists, but the Edge Function inventory returned no deployed functions in Staging.
- No hidden or unpublished client depends on the existing direct privileges.

Absence of PostgREST entries in the available logs is not proof of absence of callers.

## 8. Rehearsal acceptance tests

After external-caller clearance and separate execution approval, test on Staging only:

1. Logged-out browser: no direct access to protected tables/sequences.
2. Student: profile read, education catalogue, published exam, attempt start/resume, answer save, timing sync, submit, result and history.
3. Admin: profile list/update, exam editor, version create/save/publish, education placement, reports and import flow.
4. Direct table REST probes: denied where intended; `profiles` and `exams` SELECT remain functional for authenticated users.
5. RPC-only workflows continue to work through the 40-function allowlist.
6. Verify sequence-backed inserts/defaults through real supported workflows; do not call `nextval` or `setval` directly as a client test.
7. Re-run catalog ACL assertions and compare protected data counts/fingerprints before and after.

User-reported E2E is required for authenticated browser flows; the assistant must not claim independent browser testing without an authenticated browser session.

## 9. Explicit non-goals

- No Production ACL change.
- No merge to `main`.
- No migration generation or application.
- No change to the 40-function allowlist or function bodies.
- No change to RLS policies, Storage, Auth, role membership, schema ownership, table ownership or sequence ownership.
- No data deletion, archive, cleanup or sequence reset.
- No retirement of Legacy routes, RPCs, import pipeline or Service Worker.

## 10. Phase 16 exit criteria

Phase 16 is design-complete only when:
- Snapshot query and rollback generator are reviewed.
- Remediation draft has complete preflight and postflight assertions.
- Rollback generator has a saved snapshot fixture and its emitted SQL is manually reviewed.
- External-caller gate remains explicitly tracked and is not misrepresented as passed.
- All artifacts are committed to this isolated audit branch and verified by rereading.

**Current decision:** Design artifacts only. Do not execute the remediation draft or generated rollback. No Staging or Production changes are authorized by this phase.
