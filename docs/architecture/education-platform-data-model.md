# Education Platform — Database Model and API Contract

Status: Implemented additively on Staging; not applied to Production.
Staging migrations: 20261113155228, 20261113155356, 20261113155742, 20261113160130, 20261113160231, 20261113161654, 20261114024035.

## 1. Entity relationship

```text
education_levels
  └── education_nodes (optional; parent/child, same education level)
        └── education_subjects
education_levels ─────────┘
subjects ─────────────────┘
education_subjects
  └── exams.education_subject_id
        └── exam_versions
              └── exam_version_questions
                    └── question_versions / questions / answer keys

attempts and attempt_answers remain attached to their existing exam/version/question IDs.
```

## 2. Tables

### education_levels
- `id`: UUID primary key.
- `code`: unique stable identifier; currently seeded `thpt` and `university`.
- `name`, `description`, `is_active`, `display_order`, timestamps.
- Code is immutable. A level cannot be deactivated while it has active nodes or subject offerings.

### education_nodes
- `id`, `education_level_id`, optional `parent_id`.
- `node_type`: `grade`, `institution`, `program`, `major`, `custom`.
- `code`, `name`, `description`, `display_order`, `is_active`, timestamps.
- Composite parent FK ensures a parent is in the same education level.
- Root code and sibling code uniqueness are enforced.
- Parent-child type rules: grade and institution are root nodes; program nests under institution/custom; major nests under institution/program/custom; custom is flexible.
- Cycle prevention is serialized per level.
- Active nodes require an active level and active parent.
- A node cannot be deactivated while active children or active subject offerings depend on it.
- Level, parent, type and code cannot be rewritten once child nodes or subject offerings depend on the node. Display labels can be corrected.

### subjects
- Reuses M1's canonical subject catalogue.
- Existing seeded records (Toán, Đọc hiểu, Khoa học) are preserved, but are not assumed to be the complete THPT or University curriculum.
- New school subjects and university courses can be added as canonical subjects when required.

### education_subjects
- `id`, `education_level_id`, optional `education_node_id`, `subject_id`.
- `local_code`, `display_name`, `description`, `display_order`, `is_active`, timestamps.
- Composite FK enforces that an optional node belongs to the selected education level.
- A NULL node means the direct path Level → Subject → Exam. This is the default simple THPT and University path.
- A non-NULL node means the optional path Level → Context node(s) → Subject → Exam.
- One canonical subject can have distinct contextual offerings and labels, e.g. Mathematics at THPT and Calculus I under a university major.
- Active offerings require an active level and, when present, an active node.
- Offering level/node/subject identity cannot be changed once an exam references the offering. The display label may be corrected.

### exams
- Adds nullable `education_subject_id` with RESTRICT FK to `education_subjects`.
- Nullable is deliberate during the transition: legacy exams are not auto-classified.
- Database trigger rejects assignment to inactive/missing education offerings.
- Once a non-NULL placement has student attempts, it cannot be changed or cleared.
- A legacy exam with NULL placement can be classified once, even if it already has attempts.
- Mandatory placement at publication is deferred until the Admin editor and legacy exam classification queue are ready.

## 3. Current Staging seed and data state

- `education_levels`: 2 rows — THPT and Đại học.
- `education_nodes`: 0 rows; no unrequested grades/institutions/programs/majors have been invented.
- `education_subjects`: 0 rows; no curriculum mapping has been guessed.
- Existing Staging exams remain unplaced.
- Existing Staging exam/version/attempt/answer counts were unchanged by these additive migrations.

## 4. RLS and access model

- RLS enabled on all three new tables.
- Authenticated active profiles can read active education levels, active nodes under active levels, and active subject offerings under active paths.
- Admin can read active/inactive records and write the catalogue.
- Anonymous role receives no visible rows from the education catalogue.
- New Admin RPC checks `auth.uid()` and `public.is_admin()` internally.
- Student scoped catalogue RPC checks for an active profile and returns only safe exam listing fields.
- No answer keys, grading configuration, private solutions or unpublished content are returned by the new listing RPC.

## 5. RPC contracts

### `admin_set_exam_education_subject(p_exam_id uuid, p_education_subject_id uuid)`
- Active Admin only.
- Assigns or clears placement on a stable exam identity.
- Database trigger validates active offering and prevents reclassification after attempts once a non-NULL placement exists.

### `admin_save_exam_content_with_education(...)`
- New legacy-editor save contract.
- Requires a non-NULL education-subject offering.
- Saves the question content and optional category as a draft first.
- Assigns education placement within the same transaction.
- Publishes only after placement has been assigned when `p_publish=true`.
- Prevents the previous two-step failure mode where a published exam could be left unplaced if assignment failed.

### `list_published_exams_for_education_subject(p_education_subject_id uuid)`
Returns:
- `id` (exam_version_id, compatible with existing exam-room entry)
- `exam_id`
- `version_no`
- `title`
- `description`
- `duration_minutes`
- `published_at`
- `question_count`

Only active-profile users can call it. It returns only published, non-archived versions for the requested active offering.

## 6. Publication enforcement — intentionally deferred

The current staging foundation does not yet block publication of unplaced legacy exams. This is deliberate:
- The old editor does not yet select an education-subject offering.
- Existing Production exams have not been classified.
- Enforcing NOT NULL or a publication trigger now would break the legacy editor and could hide existing exam content.

The later editor integration release must:
1. Add required education placement to new/edit exam flows.
2. Provide an Admin queue for legacy unplaced exams.
3. Classify all intended-to-remain-published exams.
4. Add database-side publication enforcement.
5. Re-run all question type, import, grading, history and attempt tests.

## 7. Security and migration references

Supabase RLS follows the official Postgres RLS guidance: https://supabase.com/docs/guides/database/postgres/row-level-security

Migrations are append-only. The five Staging-only migrations listed above are not applied to Production. See `supabase/migration-recovery-manifest.json` for their current environment status.
