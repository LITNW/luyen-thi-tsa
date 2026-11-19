# Education Staging Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close the group-table RLS gap, strengthen regression checks, and document a safe operator-run Staging cutover without applying it.

**Architecture:** Keep authorization inside PostgreSQL RLS by matching the existing `education_levels` active-profile predicate and retaining its admin bypass. Extend the disposable SQL regression suite to exercise active, suspended, anonymous, and Admin roles. Document the schema/app cutover as a gated operation with a temporary restrictive RLS write freeze and exact recovery gates.

**Tech Stack:** PostgreSQL/Supabase migrations, SQL regression scripts, Node.js `node:test`, Markdown runbook, GitHub Actions.

**Spec:** User request in the active Codex thread, “Resolve PR #41 Audit Findings and Prepare Staging Cutover”.

## Global Constraints

- Do not run a migration against Staging or Production.
- Do not modify hosted data or settings, merge PR #41, or deploy Production.
- Do not disable RLS, delete legacy columns/tables, or rewrite course IDs or exam references.
- Keep PR #41 open and Draft.

## Review Focus

- Suspended authenticated profiles must not read groups; active profiles and active Admins retain intended read/write access.
- `anon` must remain unable to read groups through grants or policy.
- The group policy must not recurse through `education_levels` or `profiles` RLS.
- Existing University course creation, THPT direct creation, group reassignment, and exam references must remain covered by SQL regressions.
- The runbook must distinguish manual approval/credentials from commands and stop if backup, ledger, or dry-run gates fail.

---

### Task 1: RLS policy and SQL regression

**Files:**
- Modify: `supabase/migrations/20261119160000_education_subject_groups.sql`
- Modify: `supabase/tests/education_subject_groups_regression.sql`

- [x] Add role-based assertions for active student, suspended student, anon, and Admin (including Admin visibility of an inactive group and permitted group creation), plus a reversible University-only write-freeze policy test.
- [ ] A local SQL RED run could not be executed because no PostgreSQL client is installed and Docker Desktop's Linux engine is not running; verify the regression in CI.
- [x] Add the same active-profile predicate as `education_levels` while retaining the existing Admin branch.
- [ ] Verify focused SQL regression, full clean-install, and recovered-chain workflows.

### Task 2: Application selection contract coverage

**Files:**
- Modify: `tests/education-classification.test.js`
- Add or modify pure selector logic only if existing component contracts cannot be tested directly.

- [x] Add assertions for valid University group/course, direct THPT course, downstream selector reset, edit/reassignment, and exam save/update payloads; SQL coverage includes University exam draft creation/edit and direct THPT creation.
- [ ] Run full `npm test` suite.

### Task 3: Staging runbook

**Files:**
- Add: `docs/education-course-classification-staging-cutover.md`

- [x] Document manual backup, checksum, and restore-drill requirements.
- [x] Document baseline SQL and migration-ledger capture.
- [x] Include restrictive RLS policies that freeze University INSERT/UPDATE only; explicitly keep RLS enabled and exclude service-role writes from the freeze assumption.
- [x] Specify target-ref verification, dry-run exact-pending-set gate, single migration execution, compatible frontend release, post-release checks, and removal of the temporary policies.
- [x] Specify roll-forward and separately approved restore-to-new-project / restore-in-place procedures.
- [x] Label approval and credential boundaries explicitly.

### Task 4: Verification and review

- [ ] Run `npm test`, migration-recovery integrity check, available local SQL checks, and production build.
- [ ] Inspect the full diff and current PR checks.
- [ ] Confirm the branch remains clean after commit/push, PR remains Draft, and no hosted mutation occurred.
