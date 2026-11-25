# LIT — Product Truth (Phase A specification)

**Status:** Product context grounded in current repository and source review; unresolved questions remain open during partial implementation.
**Baseline:** PR #41 branch current HEAD `ff934cd7a2704c5133180f3a4b703464eed72c41`.
**Purpose:** Record product facts that should shape the redesign without inventing capabilities, users, metrics or business rules.

## Evidence and confidence labels

- **Verified in current product sources:** directly represented in current React routes/pages, legacy SPA states, brand/system documentation, or PR #41 Education Structure implementation. This describes current code/documentation, not a guarantee that every behavior was browser-tested.
- **Reasonable inference:** likely user intent based on the available flow, but not explicitly established as product policy.
- **Open:** source material is insufficient; do not make a design or copy decision by guessing.

Evidence was read from `src/App.jsx`, the React page modules (`PublicLandingPage.jsx`, `AuthPage.jsx`, `DashboardPage.jsx`, `EducationBrowsePages.jsx`, `HistoryPage.jsx`, `ResultsPage.jsx`, `AdminEducationPage.jsx`, `AdminPages.jsx`), `public/legacy/index.html`, existing `docs/brand/LIT-BRAND-SYSTEM.md`, and existing design docs. No live browser flow or user interview was performed for this specification.

## User groups

| Group | Status | Verified needs and product interaction |
|---|---|---|
| Learner / student | Verified current product group | Registration copy identifies a student account. Authenticated users can browse education levels/courses, open published exams, take an exam, view history and inspect results. The precise learner segments, age range and accessibility accommodations are not specified. |
| Admin | Verified current role/surface | An Admin route guard protects `/admin` pages. Existing surfaces manage exams and placement, Education Structure, exam categories, users, attempts, and import/editor workflows. Admin responsibilities beyond those screens are unspecified. |
| Unauthenticated visitor | Verified as a product state; “prospective learner” is an inference | Can see the public landing page and reach login/register. Whether all visitors are prospective learners or whether the landing page serves other audiences is not established. |
| Teacher, parent, school operator, support agent | Open | No distinct role, permissions or user journey was verified. Do not design dashboards or controls for these roles without product confirmation. |

## Core workflows supported by current source

### 1. Enter the product

1. Visitor sees the public landing route `/` while unauthenticated.
2. Visitor can go to `/login` or `/register`.
3. Registration asks for display name, email and password; the UI communicates email verification when the returned session is absent.
4. Authenticated users are directed to the dashboard at `/`.

These steps are source-visible; actual deployment settings and account eligibility are not asserted here.

### 2. Find learning content

1. Learner opens an education level.
2. THPT path is level → course/subject.
3. University path is level → Admin-managed course category → course/subject.
4. A course page lists published exams and factual exam metadata (for example duration and question count) and offers entry to the exam.
5. University default category code `unclassified` exists in the product model; do not infer a category for a course with no category.

The hierarchy and source-level query/filter behavior are verified. Whether categories have additional user-facing descriptions or personalized recommendations beyond stored content is not established.

### 3. Take an exam

The Legacy SPA contains a `take` state, question/answer interaction, timing, save/sync behavior, flagged/unanswered status, review before submit and a final submit confirmation. It also includes a pending-result state. This is a source-level workflow inventory; exact offline guarantees, timer policy and recovery service-level expectations are **open** and must not be expanded by redesign copy.

### 4. Review work

Authenticated users can open history, resume an in-progress attempt where supported, and open a submitted result. The result page shows score/status information and question-level answers/explanations. The history page currently requests a bounded first 100 records, so UI must not imply an unbounded archive unless product behavior changes under a separately approved task.

## Page-group actions and information hierarchy

| Page group | Primary user action | Information hierarchy (highest first) | Constraints |
|---|---|---|---|
| Public landing | Start registration or sign in | LIT identity and purpose → primary CTA → explanation of available learning flow | Do not add claims, outcomes, testimonials, rankings or fabricated metrics. Existing three-step/feature content should be confirmed for accuracy before rewriting. |
| Login/register | Authenticate or create an account | Page purpose → labeled fields → submit action → validation/status → alternate auth route | Preserve current auth API and session behavior. Do not imply password recovery or MFA unless verified. |
| Dashboard | Continue into learning or an available admin task | Greeting/account context → existing factual account/level metrics → education level choices → admin shortcuts where authorized | Do not invent streaks, predicted outcomes or progress percentages. Exact dashboard metrics should be tied to existing data. |
| Education browse | Select level, category or course | Current location/breadcrumb → selected level/category → available courses/exams → action | THPT is flat. University categories are generic Admin-managed data, not tied to majors. Preserve existing IDs/references. |
| Exam room | Answer questions and submit an attempt | Exam title/timer → current question and answer choices → navigation/flags/sync state → submit action | Treat time, answer state and submit confirmation as critical. Visual work must not change scoring, persistence, timing or attempt contracts. |
| History/results | Resume supported attempt or inspect a result | Attempt status/date/context → available action → score and answer/explanation details | Do not imply history is complete if bounded; do not invent comparative analytics or change result values. |
| Admin workspace | Open an administrative task | Admin identity/access context → task navigation → page-specific records/actions | Retain current role checks and all existing authorization/business contracts. |
| Admin Education Structure | Manage levels, categories and courses; edit visibility; guarded delete when allowed | Level → (University category) → course → fields/status/actions | Preserve THPT flat and University category hierarchy, `unclassified`, validation, database guards, and delete restrictions. No auto-reclassification. |
| Admin exams/categories | Review exam versions and placement or manage exam categories | Exam/version → existing education placement and status/locks; separate exam categories | Exam category is a different concept from University course category. Preserve attempt-history locks. |
| Admin users/attempts/import | Perform existing support/admin actions | Record identity/status → relevant details → authorized action and feedback | Do not infer additional support tools or expose more data than current surfaces. Import/editor details remain in Legacy during this plan. |

## Brand assets and product concepts to retain

### Verified current assets and statements

- Brand name: **LIT**, used as a standalone product name in `docs/brand/LIT-BRAND-SYSTEM.md`.
- Existing vector assets: `public/brand/lit-horizontal.svg`, `lit-horizontal-mono.svg`, `lit-symbol.svg`, `lit-symbol-mono.svg`.
- The brand document lists descriptor “Nền tảng học tập và luyện tập” and candidate tagline “Learn · Practice · Grow”; it says the logo/naming are working concepts subject to final approval. Preserve assets and proportions; do not claim trademark clearance.
- Current brand guidance says TSA remains a protected legacy/technical identifier in DB, Auth, RPC, Storage, Edge Function, cache, local/session storage, migration and integration contracts; do not globally rename it.
- Current education structure: THPT level → course; University level → Admin-managed category → course. `unclassified` is a default category code. Keep current course UUIDs and exam/attempt/history references.
- The redesign direction approved for proposal is dark-first, high-contrast, angular/editorial-tech with restrained blue. This changes visual presentation, not product policy.

### Existing concepts, not redesign opportunities

- Published exams are discovered through course/subject pages.
- Exam-taking, results, history, authoring/import and selected admin views currently include Legacy SPA surfaces.
- Existing statuses such as hidden/active/locked/pending describe operational states; preserve their meaning and provide text/icon cues.
- Existing three-step landing/auth copy and brand promise must be reviewed for accuracy, not treated as proof of any outcome guarantee.

## Assumptions and unresolved questions

| Topic | Known | Gap / question to resolve before relevant design or copy |
|---|---|---|
| Learner profile | Student account copy and learning/exam pages exist | Age groups, supported institutions, device constraints, language preferences, assistive needs and primary target cohort are unspecified. |
| Assessment purpose | Landing/auth copy refers to the Thinking Assessment exam; exams have duration/question count and results | Official exam naming, scoring scale, pass thresholds, exam formats and result interpretation are not fully documented here. Do not invent labels or coaching advice. |
| Progress metrics | Dashboard includes factual user/role/level context per source audit | Which exact metrics are useful, their definitions/time ranges, and whether to show any trend are not established. Use only current fields, label accurately, or omit. |
| Recommendations | No verified recommendation/ranking model | Do not add “recommended,” mastery, predicted score or next-best-action claims without evidence. |
| History retention | Current History page requests at most the first 100 records | Is pagination available elsewhere? Is the displayed history intended to be a complete archive? Confirm before describing it as complete. |
| Exam recovery | Legacy source contains save/sync and pending-result states | Offline guarantees, conflict resolution, retry timing, timer authority and support procedure are not specified. Preserve existing behavior; ask product owner before promises. |
| Admin authority | Admin routes and database-backed safeguards exist | Admin role assignment policy, multi-admin expectations and audit log requirements are not documented. Do not change authorization. |
| Branding | Existing guide calls logo/naming working concepts and tagline suggested | Final approval/ownership of tagline and whether the existing light palette is fully retired are open. The redesign brief approves dark-first direction but does not establish legal trademark status. |
| Legacy surfaces | Standalone SPA includes exam, editor, import, history/profile/admin states | Which states are active for real users versus compatibility/maintenance-only, and whether any are scheduled for retirement, is unclear. |
| Localization | Current UI is primarily Vietnamese with some English labels/eyebrows | Is English a supported locale? Keep existing copy language unless confirmed; avoid creating an incomplete bilingual system. |

## Product-truth boundary

This document records current product behavior and known brand guidance. It does not authorize changes to route structure, auth/access control, data model, API contracts, exam scoring, user roles, workflow semantics, marketing claims, database or production systems. Any unanswered item remains a design constraint or an explicit question, not permission to infer a capability.

## Verified implementation observation — 2026-11-25

Source review on the redesign branch found that Legacy startup attempted to restore a saved exam session for any signed-in user before distinguishing an Admin from a student. The change now limits automatic restore to the verified student context, including offline fallbacks. Account switching or sign-out detaches the previous editor/exam view and retains that student's saved attempt cache. The Admin editor has a local draft-preview path that does not create a server attempt or start the student timer, and preview exit returns to the editor draft. A separate learner exit path leaves the active attempt unsubmitted and tells the learner that saved answers are retained and exam time continues. Contract tests cover these source-level conditions; no authenticated browser session was used, so the full user journey and persistence behavior still require direct verification. These observations describe the current implementation and are not new product guarantees.
