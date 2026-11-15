# Phase 13 — Full Schema Object Parity Audit

**Date:** 2026-11-15  
**Mode:** Read-only catalog inspection  
**Production:** `hwqtsopvpucadgpkigqz`  
**Staging:** `cppalwtdkditlhojpeyc`  
**Branch:** `audit/phase-13-full-schema-object-parity-20261115`

## 1. Executive summary

Phase 13 performed SELECT-only comparisons of PostgreSQL catalogs in Production and Staging. No DDL, DML, GRANT/REVOKE, migration, extension installation/update, deployment, or application-code change was performed.

**Results:**
- Public application constraints: 166 in each environment; normalized catalog fingerprint identical.
- Public application indexes: 97 in each environment; normalized definition fingerprint identical; all indexes are valid and ready.
- Expanded non-system schema scope: 310 constraints and 244 indexes in each environment; fingerprints identical.
- Selected schema ownership/ACL fingerprint: identical.
- Public relation ownership: all 28 listed relations have matching owners (postgres); ACLs differ on 12 relations.
- Public function inventory: Production 74, Staging 72. Owner/ACL fingerprint differs, consistent with known Production-only functions and Phase 12's Staging ACL rehearsal; function-owner-only parity is not established across different inventories.
- Role attributes for the nine inspected platform/application roles: identical.
- Installed extension names: identical (5); `supabase_vault` version differs (Production 0.3.1, Staging 0.3.2).
- Default privileges differ, including the intentional Phase 12 removal of PUBLIC/anon/authenticated function EXECUTE defaults in Staging.

**Disposition:** Structural constraints/indexes pass. Phase 13 identifies a material table-level ACL drift and extension-version drift requiring separate analysis. No automatic remediation is authorized or performed. Production remains unchanged.

## 2. Method

Read-only SQL queries inspected `pg_constraint`, `pg_index`, `pg_class`, `pg_namespace`, `pg_proc`, `pg_roles`, `pg_default_acl`, and `pg_extension`; extension inventory was also retrieved through the Supabase extension-list operation. Definition fingerprints were calculated from sorted normalized catalog representations in each database. These are comparison aids, not cryptographic proof of full schema equivalence.

The expanded user-schema scope excludes `pg_catalog`, `information_schema`, and `pg_toast`. Public application-object counts are reported separately to preserve comparability with earlier audits.

## 3. Constraints and indexes

| Scope | Production | Staging | Result |
|---|---:|---:|---|
| `public` constraints | 166 | 166 | Exact fingerprint match |
| `public` indexes | 97 | 97 | Exact fingerprint match |
| All inspected non-system schemas: constraints | 310 | 310 | Exact fingerprint match |
| All inspected non-system schemas: indexes | 244 | 244 | Exact fingerprint match |
| Invalid or not-ready indexes | 0 | 0 | Pass |

Public constraints fingerprint: `205b77831ec6df6353fe73851ad11832`  
Public indexes fingerprint: `a6c0285f1ece9d34e09ebc317cec2c09`

Expanded constraints fingerprint: `8f9a5581250f54cd82bec3b71e239f9f`  
Expanded indexes fingerprint: `b4b286240a69ddf197cf25c477904c4f`

No missing/extra constraint or index was detected by these catalog comparisons.

## 4. Ownership and ACL

### 4.1 Schema ownership and ACL

The selected schema owner/ACL fingerprint matched across both projects for seven schemas:
`public`, `auth`, `storage`, `extensions`, `vault`, `realtime`, and `supabase_migrations`.

### 4.2 Public relation ownership

All 28 inspected `public` relations (tables, sequences and other relation kinds in scope) are owned by `postgres` in both environments. No relation-owner mismatch was identified.

### 4.3 Public relation ACL drift — requires attention

The following 12 relations have different raw relation ACLs between Production and Staging:

1. `attempt_answers`
2. `attempt_question_times`
3. `attempts`
4. `audit_logs`
5. `exam_solutions`
6. `exam_version_questions`
7. `exam_versions`
8. `exams`
9. `profiles`
10. `question_answer_keys`
11. `question_versions`
12. `questions`

The observed pattern is that Staging grants broad table privileges to `anon` and/or `authenticated` on these relations, while Production uses narrower grants on a number of them. For example, Production's `exam_solutions` and `question_answer_keys` ACLs list only `postgres` and `service_role`; Staging's corresponding ACLs also include `anon` and `authenticated`.

Important security interpretation:
- Table GRANTs and RLS are separate controls. Broad table privileges do not, by themselves, prove that rows are readable or writable; RLS policies still apply where enabled.
- Nevertheless, this is a larger Data API privilege surface in Staging and is not explained by the Phase 12 function-only ACL rehearsal.
- Do not assume this drift is safe merely because the four E2E groups passed.
- A dedicated table/sequence privilege review is required, including effective privileges, RLS enabled/forced flags, policy coverage, Data API exposure, and actual application call paths.

**Severity:** P1 review item. No grants were changed during Phase 13.

### 4.4 Sequences

The three application sequences in `public` were observed with matching owners and ACLs:
`audit_logs_id_seq`, `import_events_id_seq`, and `tsa_user_code_seq`.

### 4.5 Functions

Production has 74 public functions; Staging has 72. The two known Production-only signatures remain:
- `abandon_exam_attempt(uuid)`
- `save_exam_atomic(uuid, text, text, integer, jsonb, jsonb, boolean, uuid)`

Function ACL fingerprints differ, as expected from Phase 12: Staging has the rehearsed 40-function authenticated allowlist and removed anon/PUBLIC function execution paths, whereas Production was not modified. This is intentional environment drift, not a Phase 13 remediation target.

The aggregate owner/ACL fingerprint is not sufficient to prove every common function has matching ownership; exact per-signature ownership comparison should be completed alongside the function allowlist review if Production rollout is later proposed.

### 4.6 Role attributes

The inspected roles had matching attributes in both environments:
`anon`, `authenticated`, `authenticator`, `postgres`, `service_role`, `supabase_admin`, `supabase_auth_admin`, `supabase_realtime_admin`, and `supabase_storage_admin`.

Compared attributes included SUPERUSER, INHERIT, CREATEROLE, CREATEDB, LOGIN, REPLICATION, BYPASSRLS, connection limit, and validity timestamp.

## 5. Default privileges

Default privilege catalogs differ between Production and Staging. Staging's differences include the Phase 12 rehearsal:
- global default PUBLIC function EXECUTE was revoked for postgres-created future functions;
- anon/authenticated default function EXECUTE in schema public was revoked;
- service_role default was retained;
- supabase_admin defaults and Storage defaults were not intentionally modified.

Production retains its pre-rehearsal defaults. This is an expected Phase 12 environment difference, not a reason to copy Production defaults into Staging. Do not synchronize default privileges wholesale. Any future Production rollout must use a reviewed, environment-aware allowlist and rollback plan.

## 6. Installed extensions

The actual installed extension set (`pg_extension`) contains five extensions in each environment, with the same names:

| Extension | Production | Staging | Result |
|---|---:|---:|---|
| `pg_stat_statements` | 1.11 | 1.11 | Match |
| `pgcrypto` | 1.3 | 1.3 | Match |
| `plpgsql` | 1.0 | 1.0 | Match |
| `supabase_vault` | 0.3.1 | 0.3.2 | Version drift |
| `uuid-ossp` | 1.1 | 1.1 | Match |

The `supabase_vault` version mismatch is recorded as platform/extension drift. Do not run ALTER EXTENSION or attempt to downgrade/upgrade either environment as part of this audit. Confirm compatibility and Supabase-managed upgrade policy before any change.

The broader extension availability list returned by the management surface is not the installed-extension inventory; only `pg_extension` was used for the table above.

## 7. Phase 13 findings and disposition

| ID | Finding | Priority | Action |
|---|---|---|---|
| P13-01 | Constraints and indexes match across both scopes | PASS | No action |
| P13-02 | 12 public relation ACL mismatches; Staging grants are broader on sensitive relations | P1 | Separate table ACL/RLS/Data API review; no change now |
| P13-03 | Public function inventory differs by two known Production-only functions; Phase 12 ACL differences remain intentional | INFO / P1 before rollout | Keep separate environment-specific allowlists |
| P13-04 | Default function privileges differ due Phase 12 rehearsal | EXPECTED | Preserve Staging state; do not bulk-sync |
| P13-05 | `supabase_vault` 0.3.1 vs 0.3.2 | INFO | Verify platform compatibility; no extension change |
| P13-06 | Role attributes, selected schema ownership/ACL, public relation owners and public sequence ACLs match | PASS | No action |

## 8. Limitations and remaining verification

This phase did not exhaustively compare:
- every schema/table/sequence privilege as effective privileges for every role and inherited membership;
- every public function owner by common identity signature;
- role membership/admin-option details beyond prior Phase 11 evidence;
- extension-owned objects and platform-managed dependencies;
- event triggers, publications/subscriptions, foreign servers, user mappings, policies' semantic behavior, or Data API configuration;
- actual PostgREST behavior for each table-level grant.

These are not silently treated as passing. The 12 table ACL differences should be resolved analytically before any Production ACL rollout is considered.

## 9. Safety and change log

- Production: SELECT-only catalog queries; no schema/data/ACL/extension/deployment changes.
- Staging: SELECT-only catalog queries; no schema/data/ACL/extension/deployment changes.
- No migrations applied.
- No grants/revokes issued.
- No application source changed.
- No Production or Staging data modified.
- No object approved for retirement or deletion.

**Phase 13 status:** Catalog structure comparison complete; ACL/extension parity has identified follow-up items. Do not declare complete parity or proceed to Production ACL rollout until P13-02 and P13-05 have been assessed.
