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

For all 12 tables, remove direct table privileges from `anon` and `authenticated`. The draft uses `REVOKE ALL PRIVILEGES`; on PostgreSQL 17 this also covers the `MAINTAIN` privilege, in addition to the seven privileges highlighted in the Phase 14 matrix. Postflight checks include `MAINTAIN` explicitly:

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


## Phase 16 Pre-execution Evidence — 2026-11-15

### Staging identity and read-only snapshot
- Verified Supabase project ref `cppalwtdkditlhojpeyc`, project name `tsa-practice-staging`, region `ap-southeast-1`, status `ACTIVE_HEALTHY`, PostgreSQL `17.11.0.019`. Project creation timestamp: `2026-11-13T06:45:16Z`.
- Executed the checked-in Phase 16 snapshot query through the Staging SQL interface. It is a SELECT/CTE-only catalog read; no DDL, DML, GRANT, REVOKE, migration or data change was run.
- Snapshot captured at `2026-11-15T08:59:54.910022+00:00`; database `postgres`; server version `17.11`; format `phase16-acl-snapshot-v1`; MD5 fingerprint `17683a067e185a1543e9e53d841ac2f2`.
- Preflight evidence: Staging bootstrap sentinel true; exactly 12/12 target tables, 3/3 target sequences, and 4/4 default-ACL scopes were found.
- All 12 target tables currently grant the full PostgreSQL 17 table privilege set (including `MAINTAIN`) to both `anon` and `authenticated`. `profiles.display_name` has column-level `UPDATE` for `authenticated`. Each of the three target sequences grants `SELECT`, `UPDATE`, and `USAGE` to both client roles. Both `postgres/public` and `supabase_admin/public` sequence default ACLs grant those three privileges to both client roles; both global scopes have no catalog override.
- Snapshot artifact: [phase-16-staging-acl-snapshot-20261115.json](evidence/phase-16-staging-acl-snapshot-20261115.json).

### Generated rollback and grantor limitation
- The rollback generator consumed the exact exported snapshot and returned a 23,195-character SQL artifact containing 223 GRANT statements, 223 matching `SET ROLE` statements, and 20 baseline REVOKE statements. It has no COMMIT and is not executed.
- A read-only role check found SQL executor `postgres`, `rolsuper=false`, membership in `postgres` true, membership in `supabase_admin` false. Therefore this executor cannot `SET ROLE supabase_admin`; the snapshot's `supabase_admin` grantor entries cannot be restored with exact grantor provenance by this execution identity.
- Updated the rollback generator and generated artifact to fail closed before `BEGIN` unless the executor can assume `supabase_admin` or is superuser. Do not remove this guard or treat the generated rollback as executable until an authorized grantor-preserving execution identity is available. The generated SQL is a recovery draft, not proof that rollback is operationally executable.
- Generated rollback artifact: [phase-16-staging-rollback-from-snapshot-20261115.sql](drafts/phase-16-staging-rollback-from-snapshot-20261115.sql).

### External Caller Gate — log evidence
- Queried Staging unified `edge_logs` over seven consecutive 24-hour windows from `2026-11-08T02:00:00Z` through `2026-11-15T02:00:00Z`, filtering REST requests for the 12 target tables and three sequence names. The first five windows returned no matching requests; however, the Staging project was not created until `2026-11-13T06:45:16Z`, so those empty windows are pre-creation and provide no caller-coverage evidence.
- In the first post-creation window (`2026-11-13T02:00Z`–`2026-11-14T02:00Z`), observed `GET /rest/v1/profiles`: 106 requests, all HTTP 200, role `authenticated`; and 5 `OPTIONS` preflight requests. Referer was the repository's Cloudflare Pages feature preview host.
- In the next window (`2026-11-14T02:00Z`–`2026-11-15T02:00Z`), observed `GET /rest/v1/profiles`: 11 requests and `GET /rest/v1/exams`: 3 requests, all HTTP 200, role `authenticated`; plus 2 `OPTIONS` requests. Referer was the repository's Vercel preview host.
- No direct REST requests were observed for the other 10 target tables or the three target sequences in the available post-creation log windows. No target-table request was observed with role `anon`; OPTIONS rows have no JWT role. PostgREST-specific logs contained only root-path health/system entries, so API path analysis used the unified `edge_logs` source, which exposed request path, method, JWT role, referer, user-agent, status and client-IP metadata.
- Observed direct callers are consistent with known repository preview clients and the already documented `profiles` / `exams` client reads. Referer and user-agent are indicators, not cryptographic caller identity; logs cannot prove the absence of a hidden script, a no-referer client, or a dormant integration.

### Gate status and next action
- **External Caller Gate remains OPEN.** Available Staging logs show no unexpected caller, but effective coverage is only approximately 43 hours after project creation, not a full seven days. User confirmation is still required that no external app, mobile client, script, dashboard, integration or direct SQL/API consumer uses the target tables/sequences with `anon` or `authenticated` credentials.
- **Rollback executability gate remains OPEN** because the current SQL execution identity cannot assume `supabase_admin`. A separate authorized grantor-preserving execution route must be established before any rehearsal.
- No Staging ACL remediation, rollback execution, Production query/change, migration, deployment, branch merge or data mutation occurred. Phase 16 remains pre-execution only.


## Phase 16 Follow-up — Owner Attestation, Grantor Capability & Generator Verification

### External caller owner attestation
- On 2026-11-15, the project owner explicitly confirmed that no mobile application, standalone script, third-party dashboard, or external service uses Supabase Staging or Production with `anon` or `authenticated` credentials to access the 12 target tables or three sequences.
- The owner identified the only known clients as the official React/Legacy website and authorized Cloudflare Pages/Vercel Preview environments.
- Treat the External Caller Gate as **owner-attested / conditionally accepted**, not as independently proven absence. The available Staging logs still cover only approximately 43 hours after project creation; referer/user-agent evidence is not cryptographic identity and dormant/no-referer callers cannot be excluded by logs alone.
- This owner attestation supersedes the earlier statement that owner confirmation was still pending. It does not alter the historical log coverage limitation.

### Read-only grantor capability verification
- Rechecked Staging through a SELECT-only catalog query. Execution identity is `postgres`, with `rolsuper=false`.
- `pg_has_role(current_user, 'supabase_admin', 'MEMBER')`, `USAGE`, and `SET` all return false. The role membership catalog contains no membership edge granting `postgres` the ability to assume `supabase_admin`.
- All 12 target tables and all three target sequences are owned by `postgres`.
- Across the snapshot's client-role ACL entries, 217 grant records have grantor `postgres`; six records have grantor `supabase_admin`. Those six are the `anon` and `authenticated` SELECT/UPDATE/USAGE entries in the `supabase_admin` / `public` sequence default ACL.
- The remediation draft explicitly requires the executor to be able to manage default privileges for both `postgres` and `supabase_admin`. The current Staging executor fails that precondition. Therefore the full remediation draft cannot pass preflight using the currently available Supabase SQL execution identity.
- Supabase documents this hosted-role restriction: `postgres` cannot act as `supabase_admin` to change privileges granted by it, and `GRANTED BY supabase_admin` is not a supported workaround for this executor. See [Supabase KB: Can't revoke a role membership granted by supabase_admin](https://supabase.com/kb/troubleshooting/cant-revoke-a-role-membership-granted-by-supabase_admin-d08922).
- Do not try to manufacture membership, change object ownership, or silently rewrite the historical grantor to `postgres`. Those actions would change the security boundary or produce a non-equivalent rollback.

### Rollback generator defect found and corrected
- A static inspection found that the generator used a standard SQL string literal containing `\\nRESET ROLE;`. With PostgreSQL standard-conforming strings, that emits literal backslash-`n` characters rather than line breaks; the generated rollback would not be valid executable SQL.
- Corrected the generator to use an escape string literal for the separator, then regenerated the rollback artifact from the same saved snapshot.
- Re-ran the generator as a SELECT-only query on Staging. The corrected output contains 223 `SET ROLE` statements and 223 standalone `RESET ROLE;` lines, with no literal backslash-`n` separators. The 223 grant operations comprise object/column/sequence GRANT statements and default-privilege GRANT statements.
- The generator and generated rollback remain fail-closed: the rollback guard still blocks execution because the current executor cannot assume `supabase_admin`. The formatting fix does not make the rollback executable.

### Decision and remaining blocker
- External Caller Gate: **owner-attested / conditionally accepted**, with the 43-hour telemetry limitation retained.
- Rollback generator syntax: **corrected and SELECT-only revalidated**.
- Grantor-preserving rollback: **blocked** for the six `supabase_admin` default-ACL entries.
- Full Staging remediation: **blocked before execution** because the remediation preflight requires the ability to alter `supabase_admin` default privileges, which the current executor does not have.
- No remediation statement, rollback statement, DDL, DML, GRANT, REVOKE, migration, role-membership change, ownership change, or Production query/change was executed in this follow-up.
- No authenticated browser E2E was run. The four E2E groups must be rerun by the project owner after a future authorized Staging ACL rehearsal; the assistant must not report them as passed before the owner supplies results.
- Safe next paths are: (1) obtain written guidance from Supabase on a supported way to manage this platform-owned default ACL, without attempting privileged workarounds; or (2) propose a separately reviewed, narrower Staging rehearsal that explicitly leaves `supabase_admin` defaults unchanged and records that residual risk. The narrower scope changes the approved target and must not be executed without separate approval.


## Phase 16 Extension — Platform Grantor Resolution & Split-Scope Design (2026-11-15)

### 1. Authoritative Supabase platform boundary
- Reviewed Supabase Knowledge Base, updated 2026-11-04: [Can't change the default privileges of supabase_admin in the public schema](https://supabase.com/kb/troubleshooting/cant-change-the-default-privileges-of-supabase_admin-in-the-public-schema-448af9).
- Supabase explicitly states that a hosted project's `postgres` role cannot alter `supabase_admin` default privileges and cannot become a member of that reserved platform role. `ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin`, `GRANT supabase_admin TO postgres`, and `SET ROLE supabase_admin` are not supported workarounds.
- The defaults apply only to objects created by `supabase_admin`; objects created by `postgres` use `postgres` defaults. Supabase says its Auth, Storage and Realtime services keep their objects in their own schemas; `supabase_admin`-owned objects in `public` come from extensions installed into `public`. Supabase recommends installing extensions in the `extensions` schema or another suitable schema rather than `public`.
- The Data API "Automatically expose new tables" setting changes the `postgres` defaults, not the `supabase_admin` defaults. Do not use that setting as a claimed fix for the platform-owned ACL.

### 2. Read-only Staging evidence
- Revalidated project ref `cppalwtdkditlhojpeyc`, database `postgres`, PostgreSQL `17.11`, current executor `postgres`, `rolsuper=false`, and the Staging bootstrap sentinel.
- All 15 target relations/sequences (12 tables + 3 sequences) are owned by `postgres`; owner mismatch count is zero.
- No relation in schema `public` is currently owned by `supabase_admin`.
- The `supabase_admin` / `public` sequence default ACL has 12 privilege entries: three each for `postgres`, `anon`, `authenticated`, and `service_role` (SELECT, UPDATE, USAGE). Exactly six entries belong to `anon` and `authenticated`. All are granted by `supabase_admin`; none has grant option.
- The six client-role entries are not ACLs on the existing three target sequences. They are defaults that would apply only to future sequences created by `supabase_admin` in `public`. The three existing target sequences are `postgres`-owned and their effective client privileges are separate object ACLs.
- Current effective privileges on all 12 target tables and all three target sequences remain broad for `anon` and `authenticated`; this is the existing state that the proposed postgres-owned object remediation is intended to correct. No ACL was changed by this evidence query.

### 3. Revised split-scope remediation
- **Mutable project-owned scope:** all 12 target tables, three target sequences, `profiles.display_name` column ACL, and `postgres` sequence default ACLs (global and `public`) remain in the remediation target. The script now preflights that all 15 target objects are owned by `postgres`, and fails closed if this ownership invariant changes.
- **Immutable platform-managed scope:** retain the `supabase_admin` default ACL in the snapshot and its fingerprint, but do not issue `ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin`, do not attempt `SET ROLE supabase_admin`, and do not synthesize grants that claim to restore its grantor.
- The remediation preflight now asserts the known `supabase_admin/public` sequence default ACL raw value. The postflight asserts it remains exactly unchanged and that no unexpected global `supabase_admin` sequence default ACL appears.
- The remediation still requires effective `anon` table privileges to be zero across all 12 tables; `authenticated` receives SELECT only on `profiles` and `exams`, and zero table privileges on the other ten. Both client roles must have zero effective privileges on all three existing target sequences and no `UPDATE(display_name)` column privilege.
- The script removes the impossible preflight requirement to assume `supabase_admin`; it still requires authority over `postgres` defaults and verifies the exact platform ACL instead of modifying it.
- Residual risk is explicit: if an extension or other operation creates an object owned by `supabase_admin` in `public`, the platform defaults may grant client-role privileges to that new object. The current project has zero such objects. Keep extension installation out of `public` where supported, and add an ownership/ACL review for any future extension installation or platform-owned object appearing in `public`. This exception does not weaken the ACL target for the current 15 postgres-owned objects.

### 4. Revised rollback generator
- Rollback generation now restores only client-role grants whose grantor is `postgres`, including `postgres` global/schema-specific sequence defaults.
- The generator validates the snapshot's `supabase_admin/public` sequence default ACL against the captured baseline, but deliberately emits no `SET ROLE supabase_admin` or `ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin` statement.
- The generator fails closed if any client-role grant on a target object or the `postgres` default ACL has an unexpected grantor other than `postgres`. It checks that the execution identity can assume `postgres`, not `supabase_admin`.
- Re-ran the generator as a SELECT-only query on Staging against the saved snapshot. Output: 217 `SET ROLE` statements, 217 matching `RESET ROLE;` lines, 211 direct `GRANT` statements plus six default-privilege `ALTER ... GRANT` statements; no `supabase_admin` role switch, no `ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin`, and no `COMMIT`.
- The generated rollback is a reviewed recovery artifact, not an executed rollback. It still requires a future rehearsal and a post-restore snapshot comparison.

### 5. Verification and decision
- Updated design files:
  - `docs/architecture/drafts/phase-16-staging-acl-remediation-draft.sql`
  - `docs/architecture/drafts/phase-16-rollback-generator.sql`
  - `docs/architecture/drafts/phase-16-staging-rollback-from-snapshot-20261115.sql`
- Snapshot SQL remains read-only and continues to capture all four default-ACL scopes, including the platform-managed scope, so the baseline remains auditable.
- Static review confirms the remediation draft contains no executable `ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin` statement. It intentionally retains preflight/postflight reads of that ACL.
- The rollback generator was executed only as a SELECT query to produce SQL text. The remediation draft and generated rollback were not executed.
- **Platform Grantor Resolution: resolved by supported exclusion**, not by acquiring platform role membership. The six client-role default-ACL entries are documented as immutable platform defaults for future platform-owned objects; they do not apply to the existing postgres-owned targets.
- **Design status:** split-scope design is prepared and SELECT-only generator output is validated. This is not authorization to execute the Staging remediation. A separate explicit approval is still required for the Staging rehearsal; Production remains out of scope.


### 6. Additional platform-default inventory (scope clarification)
- A further SELECT-only inventory found three `supabase_admin` default-ACL categories in `public`: 32 relation privilege entries (`defaclobjtype='r'`), 12 sequence entries (`'S'`), and 4 function entries (`'f'`). These include the client-role grants documented by Supabase; the 6 sequence entries for `anon` and `authenticated` are only the client-role portion of the 12 sequence entries.
- No `supabase_admin`-owned public relations, functions, or types were found in the current Staging catalog.
- Phase 16 remains deliberately scoped to the 12 existing `postgres`-owned tables, three existing `postgres`-owned sequences, the `profiles.display_name` column ACL, and `postgres` sequence defaults. It does not attempt to rewrite `supabase_admin` table, sequence, or function defaults.
- The revised remediation preflight now fails closed if any `supabase_admin`-owned relation or function appears in `public`, even if it is not one of the 15 target objects. This makes future extension/platform-owned objects a separate review gate rather than silently applying project-owned assumptions.
- This is a scope clarification, not a claim that all platform defaults are harmless: a future extension installed into `public` may create `supabase_admin`-owned objects and inherit the platform defaults. Avoid installing extensions into `public` when the extension supports another schema; inspect ownership and ACLs after every extension installation/upgrade that can add public objects.
