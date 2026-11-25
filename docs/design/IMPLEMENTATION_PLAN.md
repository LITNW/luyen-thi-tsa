# LIT — Redesign Implementation Plan (Review Draft)

**Baseline:** PR #41 current HEAD `ff934cd7a2704c5133180f3a4b703464eed72c41`; include Education Structure changes.
**Status:** Partial implementation on the approved redesign branch; see execution status at the end. No push, merge or deployment.
**Release boundary:** keep PR #41 OPEN and DRAFT; never merge or deploy Production as part of this plan.

## Gates

- **Gate 0 — Review:** approve UI audit and design-system proposal. Baseline selection is resolved to current PR #41 HEAD.
- **Gate 1 — Product truth:** complete product-truth interview/context required before creating the new visual world; inspect incumbent docs/prototype and agree what remains authoritative.
- **Gate 2 — Implementation branch:** create a separate redesign branch from the approved PR #41 HEAD only after the review gate. Verify branch/working tree first and preserve existing untracked files. Keep PR #41 itself unchanged.
- **Gate 3 — Incremental delivery:** every phase keeps the application buildable and preserves existing routes/business contracts.
- **Gate 4 — Preview review:** deploy Preview only; authenticate through authorized access; no Production domain/config/database changes.

## Phases

### 1. Foundation and test baseline

- Record exact selected baseline and repository status; avoid touching untracked/generated user/agent work.
- Review existing tests and CI conditions for this branch; add browser test harness only if approved and within scope.
- Convert proposed palette/spacing/type/state rules into centralized semantic CSS variables. Remove conflicting overrides only as each surface migrates.
- Define shared primitives (buttons, fields, selected controls, status, cards/list rows, focus, dialogs) with accessibility contracts.
- Do not modify or access schema, data, RLS, migration ledger, databases or business rules.

**Exit:** build and current tests pass; token contrast audit is recorded; no unrelated working-tree changes.

### 2. React shell and navigation

- Consolidate duplicated `AdminFrame`, `EducationFrame` and authenticated shell presentation only. Keep route definitions, redirects, route guards, authentication, authorization, user/session contracts and all business/API contracts unchanged.
- Define responsive navigation and breadcrumbs; represent loading, profile error, inactive account, denied access and not-found states.
- Verify direct route refresh, browser back/forward and signed-out redirects.

**Exit:** all current routes still resolve; keyboard navigation and shell behavior verified at target widths.

### 3. Public and account entry flows

- Rework landing, login/register, dashboard and account to proposed dark-first system.
- Preserve public/authenticated split at `/`; retain factual account metrics only.
- Verify auth loading/error/validation and responsive form order.

### 4. Learning browse and history/results

- Rework education levels, categories, courses, exam list, history and results.
- Preserve THPT flat structure and University level → category → course. Keep `unclassified` behavior and existing IDs/references.
- Improve result hierarchy and math rendering fallback without changing scoring or attempt behavior.

### 5. Admin surfaces

- Rework admin home, exams, Education Structure, exam categories, users and attempts.
- Keep existing destructive-action presentation explicit and preserve the current server-guarded behavior, hidden/archived visibility, attempt locks and error feedback; do not change its authorization or business contracts.
- Distinguish Education categories from exam categories in copy/navigation.

### 6. Legacy exam and editor

- Inventory current legacy state transitions and contracts before restyling.
- Share token values/typography/controls where safe; migrate shell and responsive rules incrementally while keeping standalone legacy bootstrap operational.
- Protect exam timer, offline/queued answer behavior, submit confirmation, results, authoring, media, shared stimulus and import/review flows with regression coverage.
- Do not combine visual redesign with refactoring unrelated exam or import logic.

### 7. Quality, responsive and accessibility verification

- Run approved application unit/contract tests, build, lint/typecheck if added, browser and accessibility checks. Existing CI results may be observed for the exact commit, but redesign work must not initiate SQL, migration, database recovery or clean-install execution.
- Add/execute browser coverage for route transitions, selected/unselected state, forms, delete confirmations/blocks, exam controls and responsive shell.
- Check keyboard-only navigation, focus order/return, screen-reader names/status, zoom/reflow, reduced motion, contrast and the route-group visual acceptance checklist below.
- Inspect at 360, 390, 768, 1024 and 1440 CSS px, including long Vietnamese labels, empty/error/loading and archived records. Keep React and Legacy verification/migration as separate workstreams.

### 8. Preview deployment and sign-off

- Deploy a Vercel Preview from the separate redesign branch only. Confirm deployment commit, build and preview URL.
- Use authorized browser access; if Vercel SSO blocks access, report it and do not claim visual validation.
- Check React and legacy flows, console/network errors and responsive views. Do not use real data for destructive test interactions.
- Report exact checks, failures, remaining limitations and PR #41 state. No merge/close/Production deployment.

## Required regression contracts

- Route/auth guard visibility and direct navigation.
- THPT/University selection, category/course browsing and Education Admin selected state.
- Category code client/database rule consistency and helpful errors.
- Admin delete authorization, category/course dependency blocking, default `unclassified` protection, FK/history preservation and concurrent deletion handling.
- Exam placement/history lock and no UUID/reference changes.
- Legacy answer-save, timer, submit confirmation, result/history and authoring/import contracts.
- Layout and accessibility state coverage at responsive widths.

## Risks and controls

| Risk | Control |
|---|---|
| PR #41 is still draft and may evolve | Base separate redesign branch on the selected current PR HEAD, re-check remote SHA immediately before branch creation; do not rewrite PR branch history. |
| Legacy app is standalone and functionally sensitive | Dedicated migration phase, preserve state/API contracts, introduce interaction regression coverage before styling high-risk exam/editor surfaces. |
| Current CSS specificity and duplicate shells | Central tokens and incremental component migration; avoid global replacement that changes exam surface accidentally. |
| Proposed dark palette fails contrast for muted text/disabled controls | Verify actual token pairs and states; adjust semantic tokens before broad rollout. |
| Browser/Preview inaccessible behind SSO | Obtain authorized access through normal user sign-in; otherwise mark direct validation blocked. |
| Redesign branch includes large PR diff | Keep UI work separate; no cherry-pick/rebase/force push until exact remote relationship is reviewed. |
| Test workflows are path/branch filtered | Observe any existing result for the exact commit if available; do not initiate or rerun database/SQL workflows as part of this redesign. |

## Out of scope

Database migration/application, Staging or Production changes, data edits, destructive tests against real records, changes to authentication/authorization contracts, taxonomy redesign, PR merge/close, Production deployment, domain or environment configuration changes.

## Scope clarification: presentation only

All shell and component work in this redesign is presentation-level. It may reorganize visual layout and shared presentation components, but must preserve the existing route table, URLs/redirects, authentication, authorization, Supabase calls, schemas, RPCs, persistence, validation contracts, exam behavior and education business rules. Do not use this effort to alter APIs, server behavior, database policy or data.

Existing CI results may be read and reported for the exact commit. Do not initiate migration execution, SQL regression, database recovery, Supabase clean-install, or any other database work as part of redesign implementation. This restriction applies even when the workflow normally uses an isolated fixture. No Staging or Production database changes are part of redesign implementation. Read-only inspection may be used solely to diagnose the specifically authorized permission issue.

React and Legacy remain separate, incremental visual migration tracks. Shared visual tokens may be documented once, but do not combine their implementation, entry points, test harnesses or cutovers into a big-bang rewrite.

## Visual acceptance by route group

A route group is accepted only after direct browser screenshots and interaction review at the specified viewports. Use 360, 390, 768, 1024 and 1440 CSS px; include 200% zoom, keyboard focus, reduced-motion preference, long Vietnamese labels, and applicable loading/empty/error/disabled states. Record route, state, viewport and commit with each screenshot. Source inspection or build success alone is insufficient.

| Route group | Routes/states | Visual acceptance criteria |
|---|---|---|
| Public/auth | `/`, `/login`, `/register` | Brand assets retain proportions; hierarchy leads to one clear primary action; forms stack without clipping on mobile; errors/busy/focus states are readable; no unsupported product metrics or copy introduced. |
| Dashboard/account | Authenticated `/`, `/account` | Navigation and role-appropriate actions are clear; metrics use actual existing values with labels/units; education level selection is distinguishable at rest; profile and sign-out remain discoverable. |
| Learning browse | `/education/:levelCode`, `/category/:categoryId`, `/subject/:offeringId`, compatibility redirect | THPT remains level → course; University remains level → category → course; breadcrumbs/title/selected context are clear; exam list metadata/actions wrap cleanly; loading/empty/error states explain next step. |
| Exam/results/history | `/exam/:id`, `/history`, `/results/:attemptId` and corresponding Legacy states | Timer, answer selection, unanswered/flagged status, sync, submit review and confirmation are legible; no viewport hides a primary action; score/answer/explanation/math hierarchy is clear; nothing suggests altered attempt data. |
| Admin | `/admin`, `/admin/exams`, `/admin/education`, `/admin/categories`, `/admin/users`, `/admin/attempts` | Education categories are distinguishable from exam categories; dense tables become labeled rows on mobile; selected/hidden/locked/disabled/error states do not rely on color alone; existing destructive safeguards are understandable; forms and actions fit without horizontal page overflow. |
| Legacy authoring/import | Legacy edit/import/review states and `/admin/import` | Editor controls, course placement, media/stimulus, import status and review feedback remain findable; long content does not cover save/navigation; no workflow is claimed accepted unless directly observed. |
| Route guard/system | loading, profile error, inactive, denied, not-found | No flash of restricted content; state title and recovery action are visible; focus remains logical; error text is readable and announced where appropriate. |

## Explicit exclusions

No migration, SQL execution, database recovery, clean-install run, data edit, Staging/Production database change, Supabase or Vercel configuration change, deployment, route/auth/authorization/business-contract change, PR update, merge or close. Existing CI outcomes may be observed, but the redesign does not trigger database workflows manually.

## Execution status — 2026-11-25

Work remains partial and is not release-ready. Implemented changes cover shared-token theme adoption in React and Legacy, a compact true/false matrix with independent radio groups, safe non-submitting exam exit, local Admin draft preview, and Legacy session isolation for Admins and account changes. The focused Legacy contract tests pass 10/10 and the full suite passes 84/84. A build of commit `31e91b2e7845681b62bee74b9977ffaf437a34bd` passed in a fresh source copy under `%TEMP%`; output was not copied into either worktree. The earlier in-worktree build replaced the redesign branch's pre-existing untracked `dist/`, and the exact original files could not be recovered.

Recovery evidence: `dist/` is not tracked, has no root `.gitignore` rule or Git history, and Vite is configured with `outDir: 'dist'` and `emptyOutDir: true`. The current directory contains 18 files / 836,691 bytes: 10 files copied byte-for-byte from tracked `public/` plus compiled bundles, manifest, index and generated Supabase client config. Its current SHA-256 manifest and a byte-identical copy were preserved under `%TEMP%\lit-dist-preservation-6622f8e083e2493c80766f93e5a1e4f5`. OneDrive contained no project copy; standard File History locations were absent; Volume Shadow Copy listing was blocked because the shell is not elevated. Earlier isolated build directories have different source commits and are not exact backups. Thus current content is reconstructible build output, but the original directory's exact content and any unknown untracked additions remain unrecoverable. No further operation has modified the redesign worktree's `dist/`.

The isolated local browser check covered the public landing page at 1264×712. Authenticated React pages, Admin editor/preview, student exam interactions, the requested responsive widths, keyboard behavior, and console/network checks remain unverified. No safe test backend/account was available for flows that write attempts or drafts. The requested end-to-end redesign and accessibility acceptance matrix are incomplete. Existing GitHub Actions results observed on remote PR commit `ff934cd7a2704c5133180f3a4b703464eed72c41` are successful, but no CI ran on local commit `31e91b2e7845681b62bee74b9977ffaf437a34bd`.

The `admin_delete_exam_version(uuid)` call path is Legacy UI → direct `sb.rpc(...)` → PostgREST/database function; no Edge Function or backend service route exists for it. The database function is `SECURITY DEFINER`, fixes `search_path` to empty, and checks `auth.uid()` plus trusted `public.is_admin()`. A Production-only emergency revocation file and recovery manifest explicitly say to preserve the authenticated EXECUTE revocation until a separate access-control decision; the original reason for that emergency decision is not documented. Staging already grants authenticated EXECUTE. Regranting the production role would contradict the recorded security hold, while a service-role Edge Function would require a new backend path and deployment; neither was introduced. Staging has an unrelated pending Education Structure delete-guard migration `20261124100000_education_structure_delete_guards.sql`. No migration was created or applied, and neither database was changed. The permission error remains unresolved pending a separate access-control decision and an authorized deployment path.

### Recovery follow-up — 2026-11-25

- Added a focused authentication-copy contract test and replaced internal Supabase configuration details with a user-facing service-availability message in React and Legacy. Removed the React login note that described the ongoing migration. This does not change authentication behavior or configuration.
- Focused copy tests pass 3/3; the complete Node test suite passes 87/87. `npm.cmd test` could not run because npm is not available in this shell; the same suite was run directly with `node --test`.
- Built the current source in a fresh `%TEMP%` copy created from `git archive` plus only the three edited UI files. Vite 7.3.8 transformed 101 modules and built successfully; Legacy config generation also completed. The output stayed in the temporary copy. This does not alter or recover the prior `dist/` contents.
- A local browser preview confirmed the new service-availability message in React `/login` and Legacy `/legacy/index.html`, and confirmed the React migration note is absent. The preview had no Supabase credentials; auth flows, Admin/Student journeys, responsive widths, keyboard behavior, and console/network health remain unverified.
- Rechecked the preserved `dist/` snapshot after verification: 18 of 18 files match the preserved SHA-256 manifest (`915EA2F565D804367844C9A9B6A783D61BA1D241560682BCDAFAB0ABBB877CA8`). The unknown pre-incident contents remain unrecovered.
- GitHub read-only check confirms PR #41 remains OPEN, DRAFT, and unmerged at `ff934cd7a2704c5133180f3a4b703464eed72c41`. No push, PR update, deployment, Staging write, or Production write was performed in this follow-up.

The recovery effort is still incomplete and is not release-ready. The observed copy correction and passing build/tests do not establish that the full Admin/Student workflows, exam experience, access-control behavior, responsive design, or accessibility acceptance criteria pass.
