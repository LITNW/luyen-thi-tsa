# Supabase migration history recovery

## What was recovered

The Production database has 17 rows in `supabase_migrations.schema_migrations`. Each row contains one original SQL statement in `statements[1]`. Those SQL bodies have been restored as files under `supabase/migrations`, retaining their original Production versions and names.

`migration-recovery-manifest.json` records the source version, name, and MD5 fingerprint for each original statement. The integrity workflow verifies that each recovered SQL body matches its Production fingerprint.

One exception is deliberate: `first_admin_verified_email_bootstrap` contains a deployment-specific email allowlist value. That value is redacted in Git and replaced by `SET_ADMIN_EMAIL_BEFORE_APPLY`. Its manifest fingerprint refers to the original Production SQL before redaction. Do not apply this recovery copy to a new environment until the placeholder has been replaced with that environment's intended verified administrator email.

## Why the repository and Production diverged

The Supabase migration ledger contains the SQL statements, but the original GitHub PR #1 changed only `index.html`; the database DDL/RPC work described in that PR was not committed as migration files. The database and Git therefore evolved through separate change paths.

## Active migration directory

- The 17 recovered files match the 17 Production ledger versions.
- `20261112050000_ai_exam_import_staging.sql` is a pending migration that was not present in the Production ledger. It was moved after the latest applied Production version (`20261112041845`) because its former timestamp sorted before already-applied migrations.
- Three superseded files were moved to `supabase/migration_archive/`: the duplicate offline-sync file and the incomplete delete/archive drafts. Their SQL is retained for provenance but is no longer in the active migration directory.

## Important limitation: pre-005 schema

The first recovered Production migration is labelled `005` in its SQL comments. The database already had the base `profiles`, `exams`, `exam_solutions`, `attempts`, and `audit_logs` structures before that point. Earlier setup work (including the question-bank/versioning and attempt/scoring setup commonly referred to as migrations 003 and 004) was run through the Supabase SQL Editor and is not represented in the 17-row migration ledger.

The live database currently has the profile extension objects, question/version tables, answer-key tables, attempt answer/time tables, helper functions, triggers, and RLS policies. The original SQL for the pre-005 setup has not yet been recovered as a complete, reproducible chain. Do not claim this repository can initialize a completely empty Supabase project until that baseline is reconstructed and tested.

## Safety status

- No Production migration was applied during this recovery.
- No Production migration-history row was changed.
- No exam, question, answer-key, profile, or attempt data was modified.
- This branch is for review and CI verification only. The migration history should not be repaired in Production until the pre-005 baseline and deployment sequence have been reviewed.
