# PR #41 — Education Classification Staging Cutover Runbook

Status: **prepared, not executed**. This document does not authorize a Staging or Production change. The current Preview database is not considered synchronized with this branch.

## Scope and fixed target

- Repository: `LITNW/luyen-thi-tsa`
- Branch: `fix/education-empty-uuid-payload`
- Already applied on Staging: `20261119160000_education_course_categories.sql` (verified read-only 2026-11-24)
- Pending in PR #41: `20261124100000_education_structure_delete_guards.sql`
- Staging Supabase project ref: `cppalwtdkditlhojpeyc`
- Production Supabase project ref: `hwqtsopvpucadgpkigqz` — **not a target in this runbook**

The category-aware Admin UI and category schema are already present on Staging. The pending migration adds database-level deletion safeguards. Do not apply it as part of Preview deployment; any future Staging application still requires the backup, dry-run, and explicit release gates below. No temporary write-freeze policy is part of the target design.

## Approval and credential gates

| Step | Required access | Manual approval |
|---|---|---|
| Inspect/download or create a database backup | Staging project owner / authorized database operator; database password or Dashboard access | Staging owner confirms backup window and retention |
| Restore a backup to a disposable project and inspect it | Supabase organization/project creation and database credentials | Project owner approves any temporary project or cost |
| Apply the migration | Supabase CLI login plus Staging database password/credentials | Explicit approval to apply this one Staging migration after the dry-run gate |
| Deploy the compatible frontend | Staging deployment credentials | Release owner approves the exact commit and Staging target |
| Restore Staging in place | Supabase project owner and restore permissions | Separate explicit approval after loss window, downtime, and snapshot are reviewed |

Never place database passwords, access tokens, or backup files in this repository, command history, CI logs, or PR comments. Do not use a Production connection string or ref.

## 0. Freeze the release inputs

The release operator records and verifies:

1. `git rev-parse HEAD` equals the approved PR head; `git status --porcelain` is empty.
2. PR #41 is still open and Draft, and required CI checks pass.
3. The Staging deployment artifact was built from that exact commit, not from an unsynchronized Preview database.
4. `supabase --version` is `3.2.0`, the version used for the Staging operator workflow, or the operator has checked the current CLI help and updated these commands. CLI v3 is local-by-default and deprecates the old `--linked` / `--project-ref` aliases; every remote command below names the Staging ref explicitly.
5. The operator opens the Staging project and verifies its ref is `cppalwtdkditlhojpeyc` before entering any credential or starting any write step.

Stop if the target ref, commit, artifact, ledger, or required CI state differs.

## 1. Back up Staging and prove recovery

1. In Supabase Dashboard, open **Staging → Database → Backups**. The operator must confirm a usable database recovery point predating the cutover. Do not assume daily backups or PITR are enabled; plan and recovery-point availability vary by project. If no suitable platform backup exists, arrange a full database backup before continuing.
2. Create an additional custom-format logical database dump through an approved private operator host. Use the Staging connection details from the Dashboard, a private `PGSERVICEFILE` and `PGPASSFILE` with owner-only permissions, and a PostgreSQL 17-compatible `pg_dump`:

   ```sh
   umask 077
   export PGSERVICEFILE=/secure/operator/staging-pg-service.conf
   export PGPASSFILE=/secure/operator/staging-pgpass
   BACKUP_DIR=/secure/backups/lit-staging-education-cutover
   BACKUP_FILE="$BACKUP_DIR/staging-pre-education-categories.dump"
   mkdir -p "$BACKUP_DIR"
   pg_dump "service=education_staging_backup" \
     --format=custom --no-owner --no-acl \
     --file="$BACKUP_FILE"
   sha256sum "$BACKUP_FILE" | tee "$BACKUP_FILE.sha256"
   pg_restore --list "$BACKUP_FILE" > "$BACKUP_FILE.contents.txt"
   test -s "$BACKUP_FILE" && test -s "$BACKUP_FILE.contents.txt"
   ```

   The private service file must identify the Staging database; the passfile stores the password and must not be committed. `pg_restore --list` checks archive readability, not recoverability by itself.
3. Restore the selected platform backup (or the logical dump, if that is the approved recovery source) into a separate disposable Supabase project/database. Do not restore over Staging for this drill. Query that restored copy and confirm it has the expected public schema, migration ledger, course rows, exam references, and no broken course FKs. Record the backup identifier/time, restore target, checksum, and verification results in the change record. If the restore cannot be completed and inspected, **stop**.
4. Database backups do not include Storage file bytes. This migration does not modify Storage; if the recovery plan expands to a full project restore, include a separately verified Storage-object backup or document that limitation and obtain owner acceptance.

## 2. Capture the live baseline

Run these read-only queries against the explicitly verified Staging project. Save output with the backup record; course IDs and exam references are the comparison set for post-migration verification.

```sql
select l.code as level_code, count(*) as course_count
from public.education_subjects es
join public.education_levels l on l.id=es.education_level_id
group by l.code
order by l.code;

select l.code as level_code, es.id, es.local_code, es.display_name,
       es.education_node_id, es.subject_id, es.is_active
from public.education_subjects es
join public.education_levels l on l.id=es.education_level_id
order by l.code, es.id;

select e.id as exam_id, e.education_subject_id
from public.exams e
where e.education_subject_id is not null
order by e.id;

select count(*) as broken_exam_course_refs
from public.exams e
left join public.education_subjects es on es.id=e.education_subject_id
where e.education_subject_id is not null and es.id is null;

select version, name from supabase_migrations.schema_migrations order by version;
```

Read-only baseline captured on 2026-11-19: **2 courses** (THPT 1, University 1), **3 linked exams**, **0 broken exam references**. Re-capture immediately before cutover; the old snapshot is not a substitute for a fresh baseline. Do not run `migration repair` to reconcile ledger versions.

## 3. Coordinate the schema and frontend cutover

The target migration enforces the new University category relationship. Deploy the category-aware frontend in the same release window; the legacy editor is not compatible with the new schema. Do not recreate the obsolete `staging_pause_university_course_insert` or `staging_pause_university_course_update` policies. Keep the release window short (target under five minutes) and verify the deployed frontend points to the Staging project.

## 4. Reconcile the Staging migration history with the fail-closed adapter

**Current state verified read-only on 2026-11-24.** Staging has 39 ledger rows, including `20261119160000_education_course_categories`. The remote SQL statement fingerprints were compared with the repository and environment-specific SQL evidence. The complete mapping is in `ops/staging-history/staging-history-manifest.json`; the read-only SQL check is `ops/staging-history/preflight.sql`.

The adapter under `ops/staging-history/supabase/migrations` contains one marker file for each version already applied on Staging. Every marker intentionally raises an exception if executed. The canonical migration chain under `supabase/migrations` is unchanged and remains the source for clean installs and Production. Never use the adapter for a fresh database, local reset, Preview branch, or Production.

Required sequence:

1. Open `ops/staging-history/preflight.sql` and run it read-only against Staging project `cppalwtdkditlhojpeyc`. The first query must return zero rows; the ledger count must be 39; `education_course_categories` and `education_subjects.category_id` must exist; obsolete temporary write-freeze policies must be absent; and the new delete-guard triggers must not already exist without their migration ledger row. If any check differs, stop.
2. Use Supabase CLI `3.2.0` and validate the adapter config locally, then use the adapter workdir, not the root migration folder:

   ```powershell
   supabase config validate --workdir ops/staging-history
   ```

   This config validation is local-only; it does not contact the hosted project.

   ```powershell
   supabase --workdir ops/staging-history db push --remote=cppalwtdkditlhojpeyc --dry-run
   ```

3. The dry-run must list exactly one pending migration: `20261124100000_education_structure_delete_guards.sql`. No marker file, historical migration, or other SQL may be pending. If any marker appears, stop; do not run the non-dry-run command.
4. Reconfirm the backup/restore evidence and fresh course UUID/exam-reference baseline. Only then apply the one deletion-guard migration:

   ```powershell
   supabase --workdir ops/staging-history db push --remote=cppalwtdkditlhojpeyc
   ```

5. If the migration is partially present without its ledger row, stop and prepare a reviewed forward-recovery migration. Do not rerun the migration or mutate the ledger.

Do not use `--include-all`, `migration repair`, manual ledger edits, or the root canonical migration directory against Staging. No migration-history reconciliation or migration application is authorized for Production. The Production ledger is reference-only.

## 5. Deploy and verify the compatible frontend

1. Deploy the approved PR #41 frontend artifact to the Staging frontend using the release owner’s normal Staging deployment mechanism. This is a manual release action; no Production deployment is authorized.
2. Verify the deployed artifact commit matches the migration-tested PR head. Inspect its runtime configuration and confirm its Supabase API URL/project ref resolves to `cppalwtdkditlhojpeyc`. Do not infer this from the hostname or from a Preview deployment.
3. With an active Admin account, verify categories load, create/edit/reorder a temporary category, create a University course assigned to a category, edit and move it to another category, and create/edit an exam draft assigned to that course. Verify a THPT course can be created with no category and used by the exam selector. With an active student account, verify level → category → course browsing and the course exam page work.
4. Compare the baseline and post-migration course ID set and exam `(id, education_subject_id)` pairs. Expected data checks: original course IDs and exam refs are unchanged; baseline University course is now in `unclassified`; all THPT courses have `category_id IS NULL`; no University course has a null or cross-level category; broken exam references remain zero. Account explicitly for any disposable smoke-test records before comparing counts.
5. Archive the smoke-test exam and deactivate the smoke-test course before deactivating any test-only category. Do not delete existing course rows or rewrite existing IDs/references.
6. If all checks pass and the release owner confirms the new frontend is operational against Staging, verify no obsolete temporary policies exist:

   ```sql
   select policyname from pg_policies
   where schemaname='public' and tablename='education_subjects'
     and policyname in ('staging_pause_university_course_insert','staging_pause_university_course_update');
   ```

   Verify University create/edit now succeeds only through the category-aware application path. Leave the permanent migration guards and RLS enabled.

## 6. Failure handling

### Before the migration commits

- Keep the cutover paused while investigating; do not recreate the obsolete write-freeze policies.
- Inspect the ledger, `education_course_categories`, `education_subjects.category_id`, triggers, and constraints read-only.
- If the migration rolled back fully and schema/ledger match the captured preflight state, the release owner may cancel the cutover and verify that no obsolete temporary freeze policies exist.
- If schema objects exist without the ledger entry, stop. Do not rerun or repair the ledger automatically; have the database owner inspect the exact state and prepare a reviewed forward-recovery migration.

### After the migration commits

- Pause the release and stop further Staging writes through operational coordination if the frontend is not confirmed healthy; do not recreate the obsolete RLS freeze policies.
- Prefer a roll-forward frontend fix/redeploy against the migrated schema. Do not try to run the old University course editor during this interval.
- If the frontend cannot be recovered and Staging must be restored, the owner first approves the exact restore point, expected lost-write window, and downtime. Take a new backup of the failed post-migration state, restore the pre-cutover backup to a separate project, and validate it. Only then may the owner separately approve an in-place Staging restore. Re-run baseline checks after restore and keep the release paused until the restored app/schema pair is confirmed operational.
- Never restore Production as part of this procedure. Never use a Staging restore as a rollback shortcut without the separate destructive restore approval.

## 7. Completion record

The release owner records: approved commit; Staging project ref; backup ID/time, checksum, restore-drill result; before/after course IDs and counts; before/after exam reference pairs; migration ledger and dry-run output; migration command result; deployed frontend commit and verified API project ref; smoke-test results; temporary-policy removal; and any remaining follow-up. PR #41 remains open and Draft until review and Staging verification are complete.

## Operator references

- Supabase [database backups and restore behavior](https://supabase.com/docs/guides/platform/backups), including restore downtime, PITR availability, and the fact that database backups do not contain Storage file bytes.
- Supabase [CLI v3 database commands](https://supabase.com/docs/reference/cli/introduction), including `db push --remote --dry-run` and the limits of `db dump` (managed schemas, data, and roles require separate consideration).
- Supabase [CLI v3 breaking-change note](https://supabase.com/changelog/supabase-cli-v3): remote targets should be explicit; CLI defaults and confirmation behavior changed.
