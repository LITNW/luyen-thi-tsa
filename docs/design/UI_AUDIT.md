# LIT — UI Audit (Phase A draft)

**Status:** Draft for review; static source audit only
**Baseline:** PR #41 current HEAD `ff934cd7a2704c5133180f3a4b703464eed72c41` (`fix/education-empty-uuid-payload`), selected by the user.
**Repository:** `LITNW/luyen-thi-tsa`
**Date:** 2026-11-25

## Scope and evidence

This audit maps the product surfaces and identifies design and implementation risks for the approved dark-first redesign. It includes the PR #41 Education Structure changes. It does not change application code, run tests, connect to a database, or claim visual/browser verification. Findings are from source inspection of routes, React pages, stylesheets, legacy markup/scripts, package metadata, existing design documents, tests, and workflow definitions. The Vercel Preview was previously observed behind Vercel Login/SSO; authentication was not bypassed. Therefore UI states, responsive behavior, console, and network have not been directly verified. All route descriptions and visual findings below are source-derived hypotheses until checked against an authenticated browser rendering; no screenshot was captured in this audit.

The current checkout has existing untracked/generated files (`dist/`, `node_modules/`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `supabase/.temp/`). They were left untouched. This report is stored outside the repository pending review.

## Product structure that the redesign must preserve

- THPT: education level → course/subject.
- University: education level → Admin-managed category → course/subject.
- `unclassified` is the default University category. Do not infer a category for uncategorized subjects.
- Keep existing course UUIDs and `exams.education_subject_id` references, attempts, answers, results, and history intact.
- Do not revive the replaced taxonomy or attach University categories to a major.

## Route and surface inventory

| Route/surface | Access | Current purpose and content | Audit notes |
|---|---|---|---|
| `/` | Public, or authenticated | Public landing when signed out; dashboard when signed in | Split behaviors make this a key entry-flow boundary. Landing has hero, static three-step preview, feature cards and CTA. Dashboard metrics are factual account/role/level data, not fabricated learning analytics. |
| `/login`, `/register` | Public | Auth form beside explanatory panel | Two-column composition; inspect narrow-screen order, field errors, pending state and keyboard focus during browser phase. |
| `/education/:levelCode` | Authenticated | Browse a level and its course/category structure | THPT is flat; University categories are grouped. Loading, empty and error states need the same visual grammar. |
| `/education/:levelCode/category/:categoryId` | Authenticated | Browse University category and its courses/exams | Breadcrumbs and category framing; category hierarchy is business-critical. |
| `/education/:levelCode/subject/:offeringId` | Authenticated | Subject/course detail and exams | Confirm title, availability and exam-list behavior in visual phase. |
| `/education/:levelCode/context/:nodeId` | Authenticated | Compatibility URL | Redirects to level route; preserve or deliberately retire only after route/analytics review. |
| `/account` | Authenticated | Profile and sign-out | Uses a legacy “TSA Practice” text mark unlike the shared LIT logo; align identity. |
| `/history` | Authenticated | Recent attempts, resume links, submitted-result links | Currently fetches a bounded first 100; communicate empty/loading/error and avoid presenting this as a complete archive. |
| `/results/:attemptId` | Authenticated | Score, status breakdown, question answers/explanations | Detailed, data-dense surface; MathJax is loaded from jsDelivr and errors are silently swallowed. Use only actual result data for visualizations. |
| `/admin` | Admin | Admin workspace shortcuts | Currently tile-oriented; redesign should distinguish high-use tasks without inventing metrics. |
| `/admin/exams` | Admin | Exam versions, level/category/course assignment and locks | Dense nested selectors. Placement can be locked after attempts to preserve history. Strong candidate for focused information hierarchy and responsive row treatment. |
| `/admin/education` | Admin | Manage level, University categories and courses | New PR #41 surface. Dense lists/forms, helper copy, visibility toggles and delete safeguards. Must retain THPT flat vs University category hierarchy and explicit code validation. |
| `/admin/categories` | Admin | Exam category CRUD | Separate domain from University course categories; name/slug/parent and active state. Keep distinction clear in nav and copy. |
| `/admin/users` | Admin | User roles/status | Privileged controls need clear scope and confirmation/error feedback. |
| `/admin/attempts` | Admin | Attempt inspection | Sensitive, data-heavy support surface; do not turn identifiers into decorative noise. |
| `/admin/import` | Admin | Redirect to legacy import editor | Route crosses from React shell to legacy SPA. |
| `/exam/:id` | Authenticated | Redirect into legacy exam-taking flow | Core high-stakes flow; preserve timers, answer sync, submit confirmation and recovery behavior. |
| `/legacy`, `/legacy/index.html` | Mixed auth/admin states | Static SPA for exam-taking, authoring, imports, history/profile and admin | Separate HTML/CSS/JS system with its own shell, dependencies and responsive breakpoints. Includes auth/home/edit/take/result/history/profile/admin users/admin attempts/import/review/pending-result states. Largest redesign regression surface. |
| `/` fallback | Public | Redirects to root | Check unknown URL recovery and avoid loops when changing route shell. |
| Route guard states | Auth/admin | Loading, profile failure, inactive account, denied access | Must be designed as first-class screens; never flash privileged content while loading. |

### Legacy functional states to include in later screen testing

Exam room; answer selection and flagged questions; shared stimulus; submit review and final confirmation; submitted/pending result; result details; editor question authoring and media; shared stimulus groups; AI import and review; history; profile; admin user and attempt views. This is not a complete screenshot inventory; route-level browser review remains outstanding.

## Visual system findings

### Current styling is split

- `src/styles.css` defines dark base tokens, then `src/lit-theme.css` applies substantial light-theme overrides to the app shell and auth/landing. The exam room has separate styling.
- `docs/brand/LIT-BRAND-SYSTEM.md` documents an incumbent light-default system and a dark exam surface. The approved brief now proposes a coherent dark-first replacement while preserving the LIT wordmark and product content.
- `AdminFrame`, `EducationFrame`, top bars and footers are repeated rather than represented by a shared app-shell/component layer.
- Legacy SPA styling is inline in `public/legacy/index.html`; its palette, controls, borders and breakpoints form a separate system.
- The stylesheets contain overlapping/hard-coded scoped rules, increasing specificity and making selected/disabled/focus states inconsistent.

### Interaction, accessibility and layout risks to validate

- Focus indicators exist in several React and exam selectors, but the rules are inconsistent and `styles.css` base focus coverage is narrower than all interactive elements (for example, `select` and `textarea` are not in the base selector). Centralize focus-visible behavior.
- Reduced-motion handling exists in `lit-theme.css`, but scope/coverage across legacy animation and all interaction transitions must be audited.
- The legacy editor uses rounded chip controls, rounded inputs/selects and pill-like chips that conflict with the approved angular direction; preserve drag/drop affordance and touch targets while restyling.
- Breakpoints vary: React styles include approximately 900/620px; theme styles 900/640px; legacy styles 800/600px; exam surfaces include 900/520px. Consolidate tokens after checking content-specific constraints.
- Some React admin navigation is horizontally dense and wraps. Confirm keyboard order, overflow and narrow viewport behavior.
- The landing page is light-oriented and the exam view is a separate visual island. The redesign should share semantic tokens while allowing task-appropriate reading surfaces.
- No chart dependency is present in package metadata. Do not add a chart merely for decoration; if a chart is approved, use actual underlying records and define accessible table/text equivalents.

## Test and CI inventory

- App scripts: `npm test` runs Node's built-in test runner; `npm run build` runs Vite and legacy-config generation. There is no lint, typecheck, component-test, browser-test, or accessibility-test script in `package.json`.
- Current tests are Node tests covering education admin structure/classification/branding, legacy contracts, result formatting, config and adapters. No browser-level route interaction suite was found in the test inventory inspected.
- Existing phase 3 design documents and HTML prototype are useful context, not evidence that screens are shipped or verified.
- `React migration CI` runs unit tests and production build. Its PR base filters do not currently include `fix/education-empty-uuid-payload`; verify GitHub's actual check coverage for the selected PR branch before relying on it.
- `Recovered migration chain smoke test` and `Supabase clean-install compatibility` have explicit steps to apply `20261124100000_education_structure_delete_guards.sql` to isolated local PostgreSQL/Supabase and execute `supabase/tests/education_structure_delete_guards_regression.sql`. Those workflow definitions demonstrate actual execution intent, not a passing run on a future redesign commit. They do not modify shared Staging/Production.
- `Migration recovery integrity` verifies recovered SQL checksums. It is not itself a behavior regression test.
- `SQL migration regression` currently targets answer-validation SQL; it is not the Education delete-guard regression.

## Prioritized findings

| Priority | Finding | Impact | Recommendation |
|---|---|---|---|
| P1 | Legacy exam/editor SPA is a separate inline system | A React-only redesign leaves major user/admin journeys inconsistent and can regress exam timing, answer persistence or authoring | Inventory legacy states and dependencies; redesign in a dedicated phase with contract/e2e coverage and no business-logic rewrite. |
| P1 | Multiple visual systems and duplicated shells | Inconsistent navigation, forms, selected states and focus behavior | Introduce semantic tokens and shared React primitives/shell incrementally; define an explicit bridge for the legacy surface. |
| P1 | Education data relationships are easy to obscure | Wrong category/course placement could damage admin workflows or historical exam links | Keep the hierarchy visible in page context and tests; preserve existing UUID and history locks; don’t conflate exam categories with University categories. |
| P2 | Responsive breakpoints and admin density differ | Wrapping/overflow and inaccessible controls likely at intermediate widths | Standardize breakpoints and define table/list transformations at 360, 768, 1024 and 1440 CSS px. |
| P2 | Focus/reduced-motion treatment is incomplete/inconsistent | Keyboard and motion-sensitive users may lose cues | Shared focus ring for every interactive control, visible non-color state, reduced-motion policy across React and legacy. |
| P2 | Results use dense text and imported math rendering | Harder scanability and risk of silent equation-rendering failure | Structure score/answer hierarchy; keep math content semantic and visible if renderer fails; show only real metrics. |
| P3 | Branding differs on account and across surfaces | Product identity feels fragmented | Use existing LIT assets consistently; preserve logo geometry. |
| P3 | Design artifacts exist but are not marked as source of truth | Prototype/spec may diverge from current product | Review phase 3 docs during screen-spec stage; update or supersede explicitly after approval. |

## Browser verification status

**Not performed.** Preview access was observed behind Vercel Login/SSO, and this audit did not bypass it. No claim is made for screenshot-level visual QA, route interactions, console/network cleanliness, screen-reader behavior, or actual responsive rendering. Those checks require an accessible Preview/browser session after implementation approval.

## Open blockers and decisions

1. Baseline is now resolved to current PR #41 HEAD `ff934cd…`. Do not base work on stale historical SHA `4c45cfa…`.
2. The user has conditionally approved these Phase A documents; the required revisions and Product Truth specification are being completed before any UI implementation.
3. Product-truth context is being documented in `PRODUCT_TRUTH.md`; unresolved product questions there must be answered or explicitly accepted before implementation.
4. Vercel Preview SSO blocks direct visual validation unless the user provides authorized access or an accessible Preview URL/session.
5. Existing checkout has untracked/generated files; keep untouched and confirm working tree before any future branch/code action.

## Screenshot and visual acceptance checklist (future browser phase)

Capture full-page and focused screenshots at 360, 390, 768, 1024, and 1440 CSS px. For each group, capture default, keyboard-focused, loading, empty/error where applicable, and the narrowest layout. Use only authorized authenticated Preview access; do not use destructive actions on real data. Label screenshots with route, viewport, visual state and commit SHA. The following is a review checklist, not a claim that these captures exist.

### React surfaces

- [ ] Public landing `/`: desktop and mobile header/hero/CTA; no clipping, unexpected horizontal scroll, or unreadable hero copy; logo proportions preserved.
- [ ] `/login` and `/register`: desktop split layout and mobile stacked layout; labels, validation/error and busy states readable; keyboard focus visible.
- [ ] Authenticated `/` dashboard: shared shell/navigation, genuine metric labels/values, level choices and admin links; selected/unselected state clear without hover.
- [ ] `/education/:levelCode`: THPT flat course listing and University category listing shown as distinct hierarchy; loading, empty and error states documented.
- [ ] `/education/:levelCode/category/:categoryId`: breadcrumb, category title, course list and empty state; no category/course hierarchy ambiguity.
- [ ] `/education/:levelCode/subject/:offeringId`: title, actual published exam details and entry action; dense metadata remains readable on mobile.
- [ ] `/account`, `/history`, `/results/:attemptId`: account identity, history status/actions, score and answer details; math content remains legible and does not overflow.
- [ ] `/admin`, `/admin/exams`, `/admin/education`, `/admin/categories`, `/admin/users`, `/admin/attempts`: nav wrapping/overflow; hierarchy and table labels; active/hidden/locked states; forms, disabled/loading/error and destructive confirmation states where relevant.
- [ ] Route guard/loading/inactive/denied/not-found states: no privileged-content flash; headings, explanatory text and recovery action visible.
- [ ] Browser console and network: record errors and failed requests for the reviewed routes; distinguish third-party failures from app defects.

### Legacy SPA surfaces

- [ ] `public/legacy/index.html` auth and home states: logo, navigation, signed-in/out state, responsive menu and main actions.
- [ ] Exam-taking state: exam title, timer, question navigation, selected answer, flagged/unanswered indicators and save/sync status; ensure no clipped controls at mobile and desktop.
- [ ] Submit review and final confirmation: dialog semantics, counts, cancel/confirm focus and busy state; capture without submitting a real attempt.
- [ ] Result and pending-result states: status, score/answer hierarchy, explanation/math content and visible retry/recovery messaging.
- [ ] History and profile states: list density, statuses and account actions remain legible and keyboard accessible.
- [ ] Editor state: education placement selectors, question text, media and shared stimulus groups; verify long content, editor controls and unsaved/error states.
- [ ] Import center and review states: upload/review actions, progress and validation/error feedback; do not upload or mutate real content.
- [ ] Admin users and attempts states: role/status/data hierarchy and action availability; no privileged control clipping or misleading status color.
- [ ] Legacy/browser console and network: record app errors separately from CDN/MathJax/PDF resource failures; verify graceful content fallback.

### Acceptance rule

A screenshot checklist item passes only after direct browser observation at the named route/state/viewport. Static source inspection, a successful build, or workflow configuration alone does not count as visual acceptance. Record failures and retest after the fix.

## Verification update — 2026-11-25

The redesign branch now includes shared-token styling for React and Legacy surfaces, plus Legacy exam and Admin preview interaction changes. A browser was used against the locally generated static build at `http://127.0.0.1:8765/`; the public landing page loaded with its Vietnamese heading, navigation, account calls to action and three-step learning-flow presentation. This confirms the rendered desktop landing surface in that generated build only.

This check does not verify an authenticated React route, any Admin/Student workflow, the Legacy exam/editor interaction, responsive widths, keyboard behavior, console/network state, or Vercel Preview. It does not satisfy the route-group screenshot acceptance matrix. All other route descriptions and interaction findings remain source-derived until checked directly.

## Scope boundary

This is a planning deliverable. No app source, tests, PR, branches, Vercel deployment, Supabase project, migration ledger, or database records were changed.
