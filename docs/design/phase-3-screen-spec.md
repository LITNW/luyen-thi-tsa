# Phase 3 — LIT screen design specification

Status: Design exploration / not production implementation  
Branch: `feature/lit-phase-3-design`  
Baseline: `main@b00f3f34ae0d06358e43a6634be4a1d52df50577`

## 1. Phase objective

Translate the approved LIT brand direction and Phase 1 UX audit into four coherent screen families. This phase is design-first. It must not change authentication, exam scoring, exam lifecycle, data contracts, database schema, RPCs, RLS, storage, legacy identifiers or production configuration.

## 2. Screen families and scope

### 3.1 Public discovery / landing

**Purpose:** explain what LIT does and route visitors to sign in or register.

- Header: LIT mark/wordmark, product navigation, sign-in and primary registration action.
- Hero: concise value proposition, one primary CTA, one secondary CTA.
- Feature strip: structured practice, progress tracking, result review.
- How it works: choose learning context → practise → review.
- Trust/clarity section: explain that available exams depend on configured learning levels and subjects; do not invent endorsements or statistics.
- Footer: product descriptor, support/legal placeholders only if approved.
- Unknown routes remain app-controlled; no new public backend dependency.

### 3.2 Student portal

**Purpose:** make the next useful learning action obvious.

- Global navigation: Overview, learning catalogue, history, account.
- Welcome panel with a clear “continue learning” action when an in-progress attempt exists.
- Learning-level cards sourced from existing education-level data.
- Recently available exams / subjects grouped by education context, not a flat undifferentiated catalogue.
- Progress summary only from existing permitted student data; do not fabricate totals.
- Empty, loading, error and offline states must be designed.
- Preserve current routes: `/`, `/education/:levelCode`, `/education/:levelCode/context/:nodeId`, `/education/:levelCode/subject/:offeringId`, `/history`, `/account`.

### 3.3 Admin workspace

**Purpose:** reduce navigation and cognitive load without weakening controls.

- Persistent admin navigation grouped by task: Learning structure; Exams and publishing; People; Attempts and reporting; Authoring/import.
- Overview panel: actionable status and recent activity only where data exists.
- Dense lists use clear columns, filters, pagination and row-level actions.
- Destructive or privilege-changing actions require explicit confirmation and clear consequences.
- Keep exam education placement distinct from optional exam category.
- Keep the legacy authoring/import link clearly identified as a legacy workflow until migration and E2E verification are complete.
- Preserve current admin routes and RPC contracts. No new permissions or privilege escalation.

### 3.4 Exam experience

**Purpose:** provide a low-distraction, resilient exam workflow.

- Dark theme with strong contrast and restrained color.
- Persistent exam identity, elapsed/remaining time where supported by the existing runtime, question navigation and save/submission state.
- Distinguish answered, unanswered, current and flagged states without color alone.
- On narrow screens, keep the question content primary and move navigation into a compact accessible panel.
- Confirm final submission; show explicit network/save state.
- Preserve the existing legacy exam runtime and its lifecycle contracts in this design phase. Do not replace or simulate scoring behavior.

## 3. Shared layout and responsive rules

- Content max width: 1200 px; reading width: 720–800 px.
- Desktop: 12-column grid; tablet: 8-column; mobile: 4-column.
- Breakpoints for design review: 1200, 900, 640 and 420 px.
- Desktop navigation may be horizontal; mobile navigation must not overflow or hide essential actions.
- Use 16–24 px page gutters on mobile and 24–40 px on desktop.
- Maintain a minimum 40 px control height; target 44 px touch targets.
- Avoid horizontal scrolling except for intentionally scrollable data tables with an accessible alternative.

## 4. Component inventory

- Brand lockup and navigation item
- Primary, secondary, tertiary and destructive buttons
- Text input, password input, select, checkbox and search field
- Status badge (published, draft, in progress, submitted, error)
- Metric tile and progress indicator
- Learning-level / subject card
- Exam card and exam list row
- Data table / responsive list
- Empty state, skeleton/loading state, inline error and success notice
- Modal/confirmation dialog
- Exam question navigator and answer-state indicator

## 5. Visual system

The light palette is the default for public, student and admin areas. The dark palette is reserved for the exam experience and optional dark contexts. Typography uses Inter with system fallbacks. See `docs/brand/lit-design-tokens.css` and `docs/brand/LIT-BRAND-SYSTEM.md`.

## 6. Acceptance criteria for design handoff

- All four screen families share the same brand, type scale, spacing and component language.
- Every screen has desktop and mobile layouts.
- Loading, empty, error, disabled and focus states are represented where relevant.
- Copy is Vietnamese-first and uses consistent product terminology.
- No invented data, endorsements, metrics or unapproved legal/support claims.
- No route, schema, RPC, auth, RLS, scoring or storage contract is changed.
- Any later implementation change must be separately reviewed, tested and delivered through Preview before Production consideration.

## 7. Known constraints and risks

- Figma MCP calls are currently blocked by the workspace Starter-plan tool-call limit. This does not block design documentation or a browser-renderable HTML prototype.
- Canva Brand Kit creation is unavailable in the connected Canva toolset and Canva Pro is not available. The repo-managed tokens and guide replace that dependency.
- The current app is hybrid React + legacy. The exam room and some authoring/import workflows remain on the legacy runtime.
- The prototype is a visual design artifact with representative sample content, not a live application and not connected to Supabase.
