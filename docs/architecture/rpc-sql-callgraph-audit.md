# Phase 9 — Supabase Project Mapping & SQL Call-Graph Audit

- **Audit date:** 2026-11-15
- **Repository:** `LITNW/luyen-thi-tsa`
- **Audited ref:** `main`
- **Commit:** `92856f1bc65cfa2a4c8a96ab17480a554dc64aba`
- **Branch for this report:** `audit/phase-9-supabase-sql-callgraph-20261115`
- **Mode:** read-only investigation; this report is the only repository artifact added by this phase.
- **Production safety:** no Production SQL was executed; no deployment, migration, secret, permission, schema, data, or runtime function was changed.

## 1. Executive findings

1. Cloudflare Pages Production and Preview point to the expected, separate Supabase projects. No frontend-to-project mismatch was found.
2. The `tsa-import-process` Edge Function source exists, and the legacy UI invokes it, but Supabase Management API lists **zero deployed Edge Functions** on both known projects. This is consistent with a missing function deployment, not a wrong frontend project reference.
3. The repository has no tracked `supabase/config.toml` and no tracked root `.env*` file at the audited commit. Vite injects the public Supabase URL and publishable key at build time.
4. All 30 active SQL migration files under `supabase/migrations/` were reviewed. Four SQL files under `supabase/migration_archive/` are archived/superseded drafts and must not be treated as active migrations.
5. Staging's live PostgreSQL catalog reports 72 functions in `public`, 33 non-internal triggers in `public`, one application trigger in `auth`, and 11 platform-managed triggers in `storage`.
6. Staging has 42 public-schema RLS policies over 22 tables. All 42 reference `public.is_admin()`; nine also reference `auth.uid()`. There are four additional import-bucket policies on `storage.objects`.
7. Some installed triggers are not attached by any `CREATE TRIGGER` statement in the currently tracked migration set. Some corresponding trigger functions are defined in migrations, but the trigger attachment is absent. Other trigger functions and the auth-user trigger are not defined in the current migration set. These are baseline/externally established dependencies whose original provenance cannot be established from this repository snapshot alone.

## 2. P0 — Frontend environment mapping

### 2.1 Cloudflare Pages configuration

Cloudflare Pages project `luyen-thi-tsa` was inspected through its read-only project metadata endpoint.

| Environment | Cloudflare build variable | Supabase URL / project ref |
|---|---|---|
| Production | `VITE_SUPABASE_URL` | `https://hwqtsopvpucadgpkigqz.supabase.co` — Production |
| Preview | `VITE_SUPABASE_URL` | `https://cppalwtdkditlhojpeyc.supabase.co` — Staging |

The Production branch is `main`; build command is `npm run build`; output directory is `dist`. The latest Production deployment inspected was `7b030e02-f508-4942-a59d-904e1a86d84c`, built from commit `92856f1bc65cfa2a4c8a96ab17480a554dc64aba`, with a successful deploy stage.

The Cloudflare project has distinct Production and Preview environment variable sets. The public publishable key is present in both environments, but its value is deliberately omitted from this report. No service-role key or other secret was retrieved or recorded.

### 2.2 Repository configuration

Relevant source:
- [`vite.config.js`](https://github.com/LITNW/luyen-thi-tsa/blob/main/vite.config.js)
- [`src/lib/supabase.js`](https://github.com/LITNW/luyen-thi-tsa/blob/main/src/lib/supabase.js)
- [`scripts/generate-legacy-config.js`](https://github.com/LITNW/luyen-thi-tsa/blob/main/scripts/generate-legacy-config.js)
- [`public/legacy/index.html`](https://github.com/LITNW/luyen-thi-tsa/blob/main/public/legacy/index.html)

Findings:
- Vite defines `import.meta.env.VITE_SUPABASE_URL` from `process.env.VITE_SUPABASE_URL`, with `SUPABASE_URL` as a fallback.
- The React client reads `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`.
- The legacy build generator writes those same build-time values to `dist/legacy/supabase-config.js`; the legacy page reads `window.__SUPABASE_CONFIG__`.
- Cloudflare Pages has the required `VITE_*` variables in both environments, so the fallback variable names are not needed for the inspected Pages build.
- No tracked `.env` / `.env.*` file was found in the repository tree at the audited commit.
- `supabase/config.toml` is absent from the tracked repository tree. This means the repo does not currently carry a standard Supabase CLI project config; it does not change the actual Cloudflare environment mapping.

### 2.3 Edge Function deployment result

- Source file: [`supabase/functions/tsa-import-process/index.ts`](https://github.com/LITNW/luyen-thi-tsa/blob/main/supabase/functions/tsa-import-process/index.ts).
- Legacy caller: `sb.functions.invoke('tsa-import-process', { body: { job_id: jobId } })` in `public/legacy/index.html`.
- Supabase Management API `list_edge_functions` returned an empty function list for:
  - Production `hwqtsopvpucadgpkigqz`
  - Staging `cppalwtdkditlhojpeyc`

**Conclusion:** the source exists and the caller exists, but there is no evidence that `tsa-import-process` is deployed to either known Supabase project. Production's frontend points to Production correctly; Preview points to Staging correctly. The missing function is therefore not explained by a Production/Preview project-ref mix-up.

The function source expects these runtime environment values: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `ANTHROPIC_API_KEY`, and `CLAUDE_MODEL`. Their live secret configuration was not inspected because the function is not deployed and secrets were outside this read-only scope. Do not infer that secrets are present or absent.

No function invocation was made, so no runtime HTTP status was observed. No deploy, secret update, or Cloudflare Pages change was attempted. Cloudflare Pages is configured as a static build (`uses_functions: false`); the missing function is a Supabase Edge Function and must be deployed/configured separately from the Pages frontend.

## 3. P1 — SQL migration inventory

### 3.1 Active migration set

The recursive repository tree was not truncated. The 30 SQL files in `supabase/migrations/` were reviewed:

1. `20261111145710_published_exam_read_access_and_admin_rls.sql`
2. `20261111145753_first_admin_verified_email_bootstrap.sql`
3. `20261111145830_admin_exam_version_workflows.sql`
4. `20261111145854_student_published_exam_read_rpcs.sql`
5. `20261111145919_consolidate_profile_update_policy.sql`
6. `20261111150635_lock_profile_role_status_updates.sql`
7. `20261111151348_admin_authoring_and_reporting.sql`
8. `20261111151520_draft_question_management.sql`
9. `20261111151651_attempt_resume_and_history_rpcs.sql`
10. `20261111151737_atomic_exam_authoring.sql`
11. `20261111151747_fix_atomic_exam_authoring_mapping_retention.sql`
12. `20261111152621_enforce_active_attempt_owner.sql`
13. `20261111152717_avoid_duplicate_question_versions_on_save.sql`
14. `20261112023553_exam_room_offline_sync_and_server_timing.sql`
15. `20261112023833_admin_delete_exam_version_safely.sql`
16. `20261112024205_archive_exam_versions_with_attempts.sql`
17. `20261112041845_normalize_dnd_slot_key_validation.sql`
18. `20261112050000_ai_exam_import_staging.sql`
19. `20261112170000_centralize_exam_answer_validation.sql`
20. `20261113100000_m1_subject_taxonomy_stimuli.sql`
21. `20261113120000_exam_categories_admin.sql`
22. `20261113140000_exam_category_archived_assignment_preservation.sql`
23. `20261113150000_exam_category_admin_list_archived_version_filter.sql`
24. `20261113155228_education_hierarchy_foundation.sql`
25. `20261113155356_education_hierarchy_active_profile_read_policies.sql`
26. `20261113155742_education_hierarchy_identity_guards.sql`
27. `20261113160130_education_exam_placement_and_scoped_catalogue.sql`
28. `20261113160231_education_exam_placement_identity_guard.sql`
29. `20261113161654_education_atomic_editor_save.sql`
30. `20261114024035_education_exam_version_publish_guard.sql`

The following four files are under `supabase/migration_archive/`, not the active migration directory:
- `20261111234000_ai_exam_import_staging_original_timestamp.sql`
- `20261112110000_exam_room_offline_sync_and_server_timing_superseded_draft.sql`
- `20261112150000_admin_delete_exam_version_safely_superseded_draft.sql`
- `20261112160000_archive_exam_versions_with_attempts_superseded_draft.sql`

They are retained as historical artifacts and were not executed.

### 3.2 Runtime catalog evidence — Staging only

Read-only catalog queries were executed against Staging `cppalwtdkditlhojpeyc` only. No SQL query was executed against Production.

| Catalog item | Staging result |
|---|---:|
| Functions in schema `public` | 72 |
| Non-internal triggers on `public` tables | 33 |
| Application trigger on `auth` | 1 |
| Triggers on `storage` tables | 11 |
| RLS policies in schema `public` | 42 |
| Public tables represented by those policies | 22 |
| Public policies referencing `is_admin()` | 42 |
| Public policies also referencing `auth.uid()` | 9 |
| Import-specific policies on `storage.objects` | 4 |

This is a Staging runtime snapshot. It is not proof that Production has an identical catalog. The repository's `migration-recovery-manifest.json` distinguishes the recovered 17-migration fingerprint set, later Production migrations, and education migrations marked Staging-only. That manifest is useful provenance but is not a substitute for a fresh Production catalog comparison, which was explicitly excluded from this task.

## 4. SQL function call graph

### 4.1 Authoring and publishing chain

The main atomic authoring path is:

```text
admin_save_exam_content_with_education
├── admin_save_exam_content_with_category     [called with p_publish = false]
│   └── admin_save_exam_content                [called with p_publish = false]
│       ├── admin_create_exam                  [only when no draft version ID is supplied]
│       ├── admin_save_question
│       │   └── validate_question_answer_key
│       ├── admin_replace_question_in_exam     [existing mapping]
│       └── admin_add_question_to_exam         [new mapping]
├── admin_set_exam_education_subject
└── admin_publish_exam_version                [only after placement, when p_publish = true]
    └── validate_question_answer_key
```

The Education-aware wrapper deliberately calls the category/content save with `p_publish = false`, assigns the education subject, and only then calls `admin_publish_exam_version` if publication was requested. This ordering is essential: the base save must not publish before the required placement exists. A standalone call to `admin_save_exam_content_with_category` has its own optional publish behavior and should not be mistaken for the Education-aware transaction boundary. Replacing only the React or legacy UI call without preserving this ordering risks publishing before placement is valid.

Other authoring relationships:
- `admin_save_question` and `admin_set_question_answer_key` call `validate_question_answer_key`.
- `admin_publish_exam_version` calls `validate_question_answer_key`.
- `admin_save_exam_content_with_category` wraps `admin_save_exam_content`.
- `admin_create_exam_version` clones the source version's question mappings directly in SQL.
- `admin_delete_exam_version` depends on the version/mapping protection triggers described below.
- `admin_set_exam_category` and `admin_set_exam_education_subject` are distinct Admin-facing operations; categories remain optional metadata while education placement is part of the current publication/navigation contract.

### 4.2 Exam-attempt chain

```text
start_exam_attempt
  └── creates or resumes the unique in-progress attempt for user + exam version

save_attempt_answer
  └── writes/deletes attempt_answers
      └── attempt_answers_guard trigger
          └── guard_attempt_child

record_attempt_question_time_v2
  ├── inserts attempt_question_time_events (event-id deduplication)
  └── aggregates into attempt_question_times

get_my_attempt_state
  └── if deadline + grace has elapsed:
      └── submit_exam_attempt

submit_exam_attempt
  ├── reads question mappings, answer keys and submitted answers
  ├── grades answers and updates attempt_answers
  └── finalizes attempts
      └── attempts_guard_update trigger
          └── guard_attempt_record
```

The `get_my_attempt_state → submit_exam_attempt` edge is a database-internal call and is not visible in the frontend's static `.rpc()` inventory. The two attempt guard triggers are implicit write-time dependencies. The new attempt-room contract must preserve ownership checks, active-profile checks, immutable attempt identity, time-window enforcement, idempotent submit, answer grading, and result/history parity.

### 4.3 RLS helper dependency

`public.is_admin()` is a shared authorization helper:
- It checks that the current `auth.uid()` maps to an active Admin profile.
- All 42 Staging public-schema RLS policies reference it.
- Admin RPCs also call it directly.
- It is a database authorization dependency, not a frontend RPC to be copied into a client-side contract.

A replacement contract must retain the policy helper or replace every dependent policy and RPC authorization path as one reviewed change. Do not retire it based only on the absence of a JavaScript caller.

## 5. Trigger inventory and classification

### 5.1 Application triggers defined in tracked migrations

| Table | Trigger | Function | Responsibility |
|---|---|---|---|
| `subjects` | `subjects_set_updated_at` | `m1_set_updated_at` | Update timestamp |
| `subjects` | `subjects_protect_code` | `m1_protect_subject_code` | Protect referenced subject identity |
| `taxonomy_nodes` | `taxonomy_nodes_set_updated_at` | `m1_set_updated_at` | Update timestamp |
| `taxonomy_nodes` | `taxonomy_nodes_prevent_cycle` | `m1_validate_taxonomy_parent` | Validate taxonomy parent/cycle |
| `taxonomy_nodes` | `taxonomy_nodes_protect_referenced_identity` | `m1_protect_referenced_taxonomy_identity` | Protect referenced taxonomy identity |
| `question_version_taxonomy` | `question_version_taxonomy_published_guard` | `m1_protect_published_question_taxonomy` | Protect published-question taxonomy |
| `question_version_taxonomy` | `question_version_taxonomy_relation_guard` | `m1_validate_question_taxonomy_relation` | Validate question/taxonomy relation |
| `stimuli` | `stimuli_set_updated_at` | `m1_set_updated_at` | Update timestamp |
| `stimulus_versions` | `stimulus_versions_immutable` | `m1_reject_stimulus_version_mutation` | Immutable stimulus versions |
| `exam_categories` | `exam_categories_set_updated_at` | `m2_set_exam_category_updated_at` | Update timestamp |
| `exam_categories` | `exam_categories_hierarchy_guard` | `m2_validate_exam_category_hierarchy` | Validate category hierarchy |
| `education_levels` | `education_levels_set_updated_at` | `education_hierarchy_set_updated_at` | Update timestamp |
| `education_nodes` | `education_nodes_set_updated_at` | `education_hierarchy_set_updated_at` | Update timestamp |
| `education_subjects` | `education_subjects_set_updated_at` | `education_hierarchy_set_updated_at` | Update timestamp |
| `education_levels` | `education_levels_guard_before_update` | `education_levels_guard` | Protect active hierarchy |
| `education_nodes` | `education_nodes_guard_before_write` | `education_nodes_guard` | Validate node hierarchy |
| `education_subjects` | `education_subjects_guard_before_write` | `education_subjects_guard` | Validate subject offering |
| `education_levels` | `education_levels_code_immutable` | `education_level_code_immutable` | Protect stable level code |
| `education_nodes` | `education_nodes_identity_guard_before_update` | `education_nodes_identity_guard` | Protect stable node identity |
| `education_subjects` | `education_subjects_identity_guard_before_update` | `education_subjects_identity_guard` | Protect stable offering identity |
| `exams` | `exams_education_placement_guard` | `education_exam_placement_guard` | Validate education placement |
| `exam_versions` | `exam_versions_education_publish_guard` | `education_exam_version_publish_guard` | Reject invalid publication |

### 5.2 Installed Staging triggers whose attachment was not found in active migrations

| Schema/table | Trigger | Function | Classification |
|---|---|---|---|
| `auth.users` | `on_auth_user_created_profile` | `handle_new_auth_user` | Auth lifecycle; creates/updates the corresponding profile |
| `public.attempt_answers` | `attempt_answers_guard` | `guard_attempt_child` | Attempt ownership/status guard |
| `public.attempts` | `attempts_guard_update` | `guard_attempt_record` | Attempt identity/history guard |
| `public.exam_version_questions` | `exam_version_questions_protected` | `protect_exam_version_questions` | Protect mappings for immutable/published versions |
| `public.exam_versions` | `exam_versions_immutable_after_publish` | `protect_exam_version` | Protect published version identity/content |
| `public.exams` | `audit_exam_changes` | `audit_exam_change` | Writes audit log entries |
| `public.profiles` | `audit_profile_changes` | `audit_profile_change` | Audits role/status changes |
| `public.profiles` | `prevent_last_active_admin` | `prevent_last_active_admin_removal` | Prevents removing the last active Admin |
| `public.profiles` | `prevent_last_admin_delete` | `prevent_last_admin_delete` | Prevents deleting the last active Admin |
| `public.question_answer_keys` | `question_answer_keys_immutable` | `prevent_answer_key_change` | Makes answer keys immutable |
| `public.question_versions` | `question_versions_immutable` | `prevent_question_version_change` | Makes question versions immutable |
| `public.questions` | `questions_identity_immutable` | `prevent_question_identity_change` | Makes question identities immutable |

Important distinction:
- `guard_attempt_child`, `guard_attempt_record`, `protect_exam_version`, and `protect_exam_version_questions` have function definitions in tracked migrations, but the trigger attachment statements were not found in the active migration files.
- The other listed application trigger functions are present in the Staging catalog but their definitions/attachments were not found in the current active migration set.
- The catalog proves that these triggers are installed in Staging; it does not identify the original migration or manual operation that installed them.
- The `auth.users` trigger is outside the `public` schema and would be missed by a public-only trigger scan.

### 5.3 Supabase Storage-managed triggers

Staging also has 11 triggers in the `storage` schema (on `storage.buckets` and `storage.objects`). These are platform-managed Storage internals, not application triggers. They are listed in the raw catalog evidence but are intentionally excluded from application retirement and replacement decisions. Do not edit or remove them as part of this project.

## 6. RLS and storage dependencies

- Staging has 42 policies across 22 public tables. Every policy references `is_admin()`; nine also use `auth.uid()`.
- The policies cover attempts and attempt child records, education levels/nodes/subjects, exam categories, exams/versions/mappings, import jobs/questions/events, profiles, question bank/version taxonomy, stimuli, subjects, and taxonomy nodes.
- Four additional `storage.objects` policies protect the `tsa-imports` bucket: Admin SELECT, INSERT, UPDATE and DELETE.
- The Edge Function uses the `tsa-imports` bucket and `import_jobs`, `import_questions`, and `import_events`. The database tables and bucket policies therefore form part of the import workflow contract even though the function itself is not deployed.

## 7. Replacement-contract implications

### Authoring

A new Authoring contract should expose a small, stable, Admin-authorized entry point and keep implementation helpers private to the database. It must preserve:
- exam/version identity and draft version creation;
- mapping identity retention for unchanged questions;
- question versioning and immutable answer keys;
- question ordering and points;
- answer-key validation;
- optional category metadata;
- required active education-subject placement;
- publication validation and immutable published versions;
- atomic save/rollback semantics.

The current Education-aware wrapper is the closest existing contract boundary. Do not replace it with several independent client writes unless equivalent atomicity and all database guards are explicitly preserved.

### Import

A replacement Import contract should preserve:
- authenticated Admin and active-profile checks;
- ownership of each import job and storage path;
- file-size/type validation;
- staged extraction into reviewable drafts (not direct publication);
- import job state transitions, progress, failure reporting and event history;
- bucket access control and the no-service-role-key-in-browser boundary.

The source function expects the Supabase and Anthropic runtime variables listed in §2.3. Deployment and secret provisioning are separate operational steps and were not authorized or attempted in this audit.

### Exam room

Do not retire or bypass attempt RPCs/triggers until a replacement passes end-to-end parity for start/resume, answer persistence, offline timing replay, deadline handling, idempotent submission, grading, and history/results.

## 8. Disposition and next steps

| Component | Disposition |
|---|---|
| `is_admin()` | Retain as shared RLS/RPC authorization helper until all policy dependencies are explicitly replaced |
| `admin_save_exam_content`, `admin_save_exam_content_with_category`, `admin_save_exam_content_with_education` | Retain until a replacement Authoring contract passes mapping/version/placement/publication regression tests |
| `validate_question_answer_key` | Retain as internal validation helper; do not expose as an independent UI workflow |
| `start_exam_attempt`, `save_attempt_answer`, `record_attempt_question_time_v2`, `submit_exam_attempt`, `get_my_attempt_state` | Retain until full Exam Room replacement parity is demonstrated |
| Attempt, version, answer-key, profile and taxonomy triggers | Retain; they enforce data integrity and historical immutability |
| `tsa-import-process` | Source exists, deployment absent on both known projects; do not invoke or retire until deployment/configuration is separately approved |
| Supabase Storage triggers | Platform-managed; out of application retirement scope |

Recommended sequence:
1. Before any Import implementation, decide the intended deployment target(s) and perform a separately approved deployment/readiness task for `tsa-import-process`; verify required secrets without exposing them.
2. Recover provenance for the catalog-only trigger attachments and baseline trigger functions from an authoritative historical schema dump or original migration source. Do not invent new migrations to recreate objects that already exist.
3. Design the Authoring replacement contract against the call graph in §4, then write regression tests for transaction atomicity, mapping retention, category optionality, education placement and publication guards.
4. Design Import and Exam Room contracts separately; do not bundle retirement with initial replacement.
5. Continue the existing observation period and require caller audit, telemetry, E2E parity and rollback planning before any legacy route/RPC/trigger retirement.

## 9. Audit boundaries and limitations

- Cloudflare Pages project settings, environment variable names/URLs, deployment metadata, GitHub source and Supabase Management API function inventory were read-only.
- PostgreSQL catalog queries were run against **Staging only** and were SELECT-only.
- No Production database connection/query was made.
- No Edge Function was invoked, deployed or modified.
- No secrets were retrieved, changed or written to this report.
- No migration was run; no schema, RLS policy, grant, table, bucket, data row or historical attempt was modified.
- No frontend/browser E2E test was performed in this phase.
- Catalog results are point-in-time Staging evidence; Production equivalence remains unverified and must not be assumed.
