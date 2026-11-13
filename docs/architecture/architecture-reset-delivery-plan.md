# Education Architecture Reset — Delivery Plan

Status: Approved direction; implementation is staged and gated.
Rule: No Production destructive operation without a verified Staging run, explicit data diff, backup and rollback path.

## Delivery units

### Phase 0 — Inventory and freeze
- Completed initial read-only Production audit and code inspection.
- Record all schema objects, row counts, FK relationships, RLS policies, RPCs and code references.
- Freeze changes to M1–M3 until the target model is accepted in the architecture PR.
- Correct stale migration-manifest status values based on the live Production ledger.
Exit: signed-off KEEP / MODIFY / REPLACE / REMOVE register; no unclassified dependency.

### Phase 1 — Product architecture
- Define Student and Admin flows, education-level semantics, optional university hierarchy and category metadata role.
- Define the canonical subject vs context-specific subject offering distinction.
- Define mandatory publication invariants and legacy exam migration queue.
Exit: architecture document, flow diagrams, entity definitions, acceptance criteria.

### Phase 2 — Database design
- Produce ERD and SQL specification for education_levels, education_nodes, education_subjects and exam placement.
- Define composite FKs, same-level parent rules, cycle prevention, active-path validation, RLS, grants and RPC contracts.
- Define backward-compatible migration and rollback plan.
- Do not apply migrations to Production.
Exit: reviewed schema design and migration test cases.

### Phase 3 — Staging data layer
- Add append-only migration(s) to create the education model and nullable exam placement.
- Seed only canonical level records (THPT, Đại học); do not invent grades, institutions, programs, majors or exam classifications.
- Add Admin RPCs and Student read RPCs with explicit authorization and no answer-key leakage.
- Run clean-install, recovered-chain, regression, security and staging tests.
Exit: Staging schema and APIs verified; old exam data unchanged.

### Phase 4 — Application UI
- Replace flat Student dashboard with education-level entry cards.
- Build data-driven context navigation, subject offerings, exam lists, breadcrumbs and empty states.
- Build Admin management for levels/nodes/subjects/offerings.
- Modify exam editor to require a valid offering before publication; keep optional category metadata separate.
- Preserve the current exam-room route and legacy editor while new authoring parity is built.
Exit: Preview E2E for THPT, simple University, extended University, Admin authoring and legacy exam room.

### Phase 5 — Compatibility, tests and retirement
- Test every question type, MathJax, matching/drag-drop, images, stimuli, AI import, publishing, grading, offline sync, resume, results, history, deletion/archive.
- Verify old attempt snapshots and all IDs remain stable.
- Remove old category-as-navigation assumptions and obsolete UI only after replacement.
- Retain category metadata as optional unless a later decision explicitly removes it.
- Do not drop old tables/functions/columns until code-reference scans, DB dependency checks and rollback window pass.
Exit: regression matrix green; no critical path depends on retired category hierarchy.

### Phase 6 — Production rollout
- Take and verify a backup; compare pre/post row counts and identifiers.
- Apply additive schema migration to Production before application code requires it.
- Deploy compatible UI, then enable mandatory publication enforcement after existing exams are classified.
- Verify Cloudflare canonical deployment, Production environment variables, RPC grants/RLS and live Student/Admin smoke tests.
- Contract/remove legacy objects only in a separate later migration after a retention window.
Exit: Production acceptance checks pass; no loss of historical data.

## PR strategy

Use separate, reviewable PRs:
1. Architecture/inventory and manifest correction (docs only).
2. Database foundation and tests.
3. Admin APIs and UI.
4. Student navigation UI.
5. Editor integration and publication enforcement.
6. Legacy retirement (only after parity).
Avoid a single large PR touching DB, UI and legacy code at once.

## Manual gates / escalation

Ask the user only when a decision or external action cannot be inferred safely:
- Admin classification of the three existing Production exam identities.
- Any request to permanently delete Production tables/data or disable existing legacy functionality before parity.
- Any paid service or non-zero cost.
- Any manual dashboard action that cannot be performed through connected tools.
- Production cutover if a safe automated backup/rollback cannot be verified.

Never request passwords, secret keys or service-role credentials in chat. Use secure dashboard flows if credentials are required.
