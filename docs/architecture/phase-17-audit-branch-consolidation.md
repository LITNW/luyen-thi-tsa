# Phase 17 — Audit Branch Consolidation & Traceability

**Date:** 2026-11-15  
**Repository:** `LITNW/luyen-thi-tsa`  
**Consolidation branch:** `audit/phase-16-staging-acl-remediation-design-20261115`  
**Base:** `main`  
**Mode:** Repository-only consolidation; no application code, migration, database, secret, or deployment changes.

## 1. Branch inventory

The following audit branches were compared with `main`:

| Branch | Ahead | Behind | Distinct purpose |
|---|---:|---:|---|
| `audit/phase-9-supabase-sql-callgraph-20261115` | 3 | 0 | Supabase project mapping and SQL call graph |
| `audit/phase-10-production-sql-parity-20261115` | 1 | 0 | Trigger provenance and Production SQL parity |
| `audit/phase-11-provenance-privilege-parity-20261115` | 2 | 0 | Dependency provenance and function privilege parity |
| `audit/phase-12-function-acl-remediation-design-20261115` | 14 | 0 | Function ACL design and Staging rehearsal evidence |
| `audit/phase-13-full-schema-object-parity-20261115` | 15 | 0 | Schema object and relation ACL parity |
| `audit/phase-14-table-acl-rls-review-20261115` | 16 | 0 | Table ACL, RLS and client-call-site review |
| `audit/phase-16-staging-acl-remediation-design-20261115` | 54 | 0 | Phase 16 design, Staging rehearsal, rollback and evidence |

All listed branches are based on the same current `main` ancestor and are not behind it. The Phase 16 branch is the cumulative audit branch. Phase 9 and Phase 10 were separate and were copied into it during this phase. Phase 17 and Phase 18 reports plus Production-specific Phase 19 draft artifacts were subsequently added to the same review branch.

## 2. Consolidated artifacts

The cumulative branch now includes:
- Phase 9 SQL call-graph report.
- Phase 10 trigger provenance and SQL parity report.
- Phase 11 provenance and function privilege parity report.
- Phase 12 function ACL design, Staging rehearsal and rollback scripts.
- Phase 13 full schema object parity report.
- Phase 14 table ACL/RLS security review.
- Phase 16 Staging ACL remediation design, guarded drafts, generated rollback, execution record, pre/post snapshots and rehearsal report.
- Phase 18 Production ACL readiness report and read-only baseline snapshot.
- Phase 19 Production-specific guarded remediation draft, Production rollback generator and generated rollback artifact.
- The reconciled migration recovery manifest.
- Phase 18 read-only Production ACL baseline evidence.

The latest compare against `main` reports 27 changed files and 62 commits ahead, 0 behind. These changes are documentation, SQL review artifacts, evidence JSON and the migration recovery manifest; no application source file or active migration file is part of the diff. Phase 18 Production baseline snapshot and Phase 19 Production-specific guarded remediation/rollback artifacts are included.

## 3. Phase 15 traceability gap

No standalone Phase 15 report was found in the listed repository branches. The Phase 15 findings currently available in the conversation and Phase 16 design record are:
- Column-level `UPDATE(display_name)` on `profiles`.
- Direct client-role privileges on three sequences: `audit_logs_id_seq`, `import_events_id_seq`, and `tsa_user_code_seq`.
- Sequence default ACL entries at global and schema-specific scopes.
- External Caller Gate clearance was supplied by the project owner based on project records; it was not independently established by a complete external traffic inventory.

This report does not fabricate a missing Phase 15 source artifact. The Phase 16 design and Production baseline document the findings needed for the current rollout scope.

## 4. Merge safety classification

The cumulative branch is **not merged**. The 21-file diff must be reviewed before a merge decision:
- Human-readable audit reports and the reconciled migration manifest are suitable for documentation review.
- Guarded SQL drafts are operational artifacts and must not be treated as migrations or run automatically.
- The Phase 16 Staging executed transaction and rollback are historical evidence, not Production scripts.
- Snapshot JSON contains environment ACL metadata and should remain clearly labelled by environment.
- No legacy component retirement or destructive deletion is authorized by this consolidation.

A draft pull request may be used for review, but merging requires separate approval after file-level review. The branch does not alter `main` or Production by itself.

## 5. Result

- Phase 9–10 reports added to the cumulative Phase 16 audit branch.
- Phase 11–16 artifacts retained without rewriting their historical evidence.
- Phase 15 artifact gap explicitly documented.
- No merge, application deployment, database operation, migration, or Production change performed.
