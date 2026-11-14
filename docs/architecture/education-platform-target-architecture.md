# Education Platform — Target Architecture

Status: Proposed implementation baseline, 2026-11-13
Scope: Student navigation, Admin authoring, education data model, exam placement, compatibility with existing TSA exam engine.

## 1. Product objective

The product is an education-structured assessment platform, not a flat catalogue of exams. Student navigation must begin with an education level and progressively narrow to a valid learning context, subject/course, and exam.

Primary Student path:

1. Choose education level (e.g. THPT, Đại học).
2. Choose the next context relevant to that level (e.g. Grade 10/11/12; or optionally institution → program → major).
3. Choose a subject / university course available in that context.
4. Browse exams for that education-subject offering.
5. Enter the existing exam room, submit, view result, and review history.

No global list of every published exam is shown as the default home experience. Search and recent activity may be added as secondary entry points, but must not bypass the education hierarchy's access and eligibility rules.

## 2. Education model

### 2.1 Core entities

- `education_levels`: top-level education domains (THPT, Đại học). Stable code, display name, active state, ordering.
- `education_nodes`: optional hierarchy nodes scoped to one education level. Examples: grade, institution, program, major. Each node has a parent, node type, stable code, label, active state, and display order. Parent/child level consistency and cycle prevention are enforced.
- `subjects`: reusable subject catalogue (M1 foundation). It is not itself the education hierarchy and does not imply that every subject is available at every level.
- `education_subjects`: a subject offering in a specific education context. It joins a subject to a terminal or selected education node, with context-specific label/code/order and active state. This allows Mathematics in Grade 10 and Calculus I in a university major to be distinct offerings while reusing a canonical subject when appropriate.
- `exams`: stable exam identity. Each exam must eventually reference exactly one `education_subjects` row before publication. Optional category metadata may remain on the exam but is never used as the education path.
- `exam_versions`, `exam_version_questions`, `questions`, `question_versions`, answer keys, solutions and attempt records remain the assessment engine.

### 2.2 Hierarchy rules

- THPT initial path: THPT → Grade 10/11/12 → subject offering → exams.
- Đại học initial path: Đại học → subject offering → exams.
- Đại học extended path: Đại học → institution → program → major → subject offering → exams.
- Intermediate university nodes are optional. The system must not force a university to create every possible level.
- A subject offering is attached to one education node. The same canonical subject may be offered in multiple nodes.
- The UI labels the selected path according to node type; it must not show empty intermediate levels.
- The hierarchy is data-driven and extensible; no separate hard-coded route per grade or institution.

### 2.3 Exam placement and mandatory rules

- Drafts may temporarily remain unplaced during migration or initial authoring, but cannot be published without a valid education-subject placement.
- A published exam must reference an active education-subject offering whose node and ancestors are active and belong to one education level.
- Student listing RPCs return only published, non-archived exam versions reachable through active education paths.
- Admin can inspect legacy unplaced exams and assign them before republishing.
- Historical attempts remain attached to their original exam/version/question identifiers. Placement changes must not rewrite historical attempt snapshots or scores.
- Optional exam category metadata is independent of education placement. It may classify purpose/type (e.g. practice, mock, midterm) but is not mandatory and does not control navigation.

## 3. Proposed relational design (to be finalized in ERD)

1. `education_levels(id, code, name, description, is_active, display_order, ...)`
2. `education_nodes(id, education_level_id, parent_id, node_type, code, name, description, display_order, is_active, ...)`
   - Unique stable code within a parent/context.
   - Composite FK ensures parent belongs to same education level.
   - Trigger/constraint prevents cycles and invalid parent node types.
3. Reuse `subjects` as canonical catalogue; consider adding subject kind only if needed by validated use cases.
4. `education_subjects(id, education_node_id, subject_id, local_code, display_name, description, display_order, is_active, ...)`
   - Unique offering per node and subject/local code.
   - Allows a context-specific course label without duplicating the global catalogue.
5. Add nullable `exams.education_subject_id` during transition, then enforce NOT NULL for published exams through a validated constraint/trigger. Do not immediately make the column globally NOT NULL while legacy drafts exist.
6. Keep `exams.category_id` optional if the product retains optional exam-purpose metadata. It is not a foreign key into the education hierarchy.

The exact constraints, indexes, policies, RPC contracts and migration ordering must be documented in an ERD and SQL design review before schema implementation.

## 4. Existing M1–M3 disposition

- M1 `subjects`: KEEP and integrate as canonical catalogue.
- M1 `taxonomy_nodes` and `question_version_taxonomy`: KEEP as optional question-level learning taxonomy; not part of Student's primary navigation.
- M1 `stimuli` and `stimulus_versions`: KEEP. They support shared passages, charts, tables, datasets and mixed stimuli; empty tables are not evidence of uselessness.
- M2 `exam_categories` and `exams.category_id`: KEEP as optional metadata unless later product evidence proves no value. Remove from the primary navigation and rename the Admin-facing concept if necessary to avoid confusing it with education levels.
- M3 category editor integration: MODIFY. Replace category-first authoring assumptions with required education placement; keep optional category metadata separate.
- Legacy exam room/editor: KEEP during transition. Replace only after the new editor passes parity tests for all question types, import, publishing, grading, offline/resume and historical results.

## 5. Student information architecture

- Home: education-level cards, recent history / continue activity as secondary modules.
- Level page: relevant active child nodes, or subjects directly when no intermediate node exists.
- Context page: subjects offered at the selected node.
- Subject page: published exams grouped/sorted by available metadata (optional type, difficulty, duration, update time).
- Exam details / start: existing exam room entry point.
- Breadcrumbs and back navigation at every hierarchy depth.
- Empty states must explain that no content is currently available; never fall back to displaying unrelated exams globally.

## 6. Admin information architecture

- Education structure: manage levels and optional hierarchy nodes.
- Subject catalogue: manage canonical subjects.
- Subject offerings: assign subjects to education nodes and set local labels/codes.
- Exam authoring: create/edit exam, assign education-subject placement, optional purpose metadata, save draft, preview, publish.
- Legacy migration queue: list unplaced exams and versions; Admin must classify each before publication under the new rules.
- Existing users, attempts, audit and reporting remain separate.

## 7. Security and invariants

- RLS enabled for every exposed table.
- Student reads only active education catalogue and published exam content reachable through that catalogue.
- Admin write RPCs check active authenticated Admin in the function body; no reliance on UI hiding alone.
- SECURITY DEFINER functions use fixed search_path, explicit auth checks, least-privilege EXECUTE grants and no anon execution.
- Never return answer keys, grading internals or unpublished content from Student catalogue RPCs.
- Foreign keys and database-side validation prevent cross-level or inactive-path exam placement.
- Do not use user-editable auth metadata for authorization.

## 8. Migration and rollout strategy

- Expand → backfill/assign → validate → switch reads/writes → contract.
- Do not edit already-applied migration files.
- Create all schema changes as append-only migrations, first applied to disposable CI DB and Staging.
- Existing exams remain unplaced until a trusted Admin classifies them; do not guess their education level or subject.
- Keep the old category field/table during the compatibility period.
- Keep legacy editor and exam room until replacement parity is proven.
- Do not drop old RPCs/tables/columns in the same release that introduces replacements.
- Production rollout must account for Cloudflare Pages auto-deploy on merge to main. Do not merge application code before the required Production schema is ready; use staged compatible changes and explicit deployment verification.

## 9. Acceptance criteria

- Student cannot land on a flat all-exams dashboard.
- THPT → grade → subject → exam works.
- Đại học → subject → exam works without mandatory institution/program/major nodes.
- Đại học extended hierarchy works when configured.
- Admin can create and edit levels, nodes, subjects, offerings and exams with valid relationships.
- Publishing without a valid active education-subject placement is rejected by the database.
- Existing exam IDs, versions, questions, answer keys, attempts, answers, timing data and historical results remain intact.
- Optional category metadata has no effect on the navigation tree.
- All legacy question types and exam-room behaviors pass regression and E2E testing before legacy code removal.
