# Supabase migration history recovery

## What was recovered

At the time of the recovery snapshot (2026-11-12), the Production database had 17 rows in `supabase_migrations.schema_migrations`. Each row contained one original SQL statement in `statements[1]`. Those SQL bodies were restored as files under `supabase/migrations`, retaining their original Production versions and names. A later read-only check on 2026-11-13 found 19 applied ledger entries: the original 17 plus `20261112050000_ai_exam_import_staging` and `20261112170000_centralize_exam_answer_validation`.

`migration-recovery-manifest.json` records the source version, name, and MD5 fingerprint for each original statement. The integrity workflow verifies that each recovered SQL body matches its Production fingerprint.

One exception is deliberate: `first_admin_verified_email_bootstrap` contains a deployment-specific email allowlist value. That value is redacted in Git and replaced by `SET_ADMIN_EMAIL_BEFORE_APPLY`. Its manifest fingerprint refers to the original Production SQL before redaction. Do not apply this recovery copy to a new environment until the placeholder has been replaced with that environment's intended verified administrator email.

## Why the repository and Production diverged

The Supabase migration ledger contains the SQL statements, but the original GitHub PR #1 changed only `index.html`; the database DDL/RPC work described in that PR was not committed as migration files. The database and Git therefore evolved through separate change paths.

## Active migration directory

- The 17 recovered files match the 17 Production ledger versions.
- `20261112050000_ai_exam_import_staging.sql` was pending at the time of recovery and was moved after the latest then-applied Production version (`20261112041845`) because its former timestamp sorted before already-applied migrations. The 2026-11-13 read-only ledger check confirms it has since been applied in Production.
- Three superseded files were moved to `supabase/migration_archive/`: the duplicate offline-sync file and the incomplete delete/archive drafts. Their SQL is retained for provenance but is no longer in the active migration directory.

## Important limitation: pre-005 schema

The first recovered Production migration is labelled `005` in its SQL comments. The database already had the base `profiles`, `exams`, `exam_solutions`, `attempts`, and `audit_logs` structures before that point. Earlier setup work (including the question-bank/versioning and attempt/scoring setup commonly referred to as migrations 003 and 004) was run through the Supabase SQL Editor and is not represented in the 17-row migration ledger.

The live database currently has the profile extension objects, question/version tables, answer-key tables, attempt answer/time tables, helper functions, triggers, and RLS policies. `pg_stat_statements` still retains a partial set of earlier DDL statements, including original `CREATE TABLE` statements for `profiles`, `exams`, `attempts`, and `audit_logs`, plus selected function, trigger, index, and policy definitions. This is corroborating evidence, not a complete historical archive: statements can be absent from the statistics, and later changes may have replaced earlier definitions. No complete, exact SQL chain for historical migrations 001–004 has been recovered.

Two explicitly test-only compatibility fixtures are maintained:

- `tests/fixtures/pre_005_schema.sql` supplies the reconstructed pre-005 schema and lightweight Auth stubs for plain PostgreSQL 16 tests.
- `tests/fixtures/pre_005_supabase_schema.sql` supplies the same reconstructed public-schema baseline while leaving Supabase-managed `auth`, `storage`, and platform roles intact. It is used only against an isolated Supabase local stack.

These fixtures are reconstructions of the schema state needed to exercise the recovered chain, not renamed historical migrations 001–004. They include selected live-catalog baseline functions needed by the runtime, including `submit_exam_attempt`, but their presence in the fixture is not evidence of the exact historical migration or timestamp in which those functions were first created. The PostgreSQL 16 chain test validates SQL ordering and dependencies against the reconstructed schema. The Supabase clean-install workflow additionally starts an isolated local Supabase stack and applies the baseline, all 17 recovered migrations, the subsequent AI-import migration, and the PR #22 answer-validation migration before running smoke/regression checks. A passing run demonstrates compatibility with that tested local stack; it does not establish that the original historical SQL was recovered byte-for-byte or that Production was modified.

## Safety status

- No Production migration was applied and no Production migration-history row was changed by the recovery work itself. The later 2026-11-13 read-only inspection observed 19 ledger entries; this repository work did not apply either subsequent migration.
- No exam, question, answer-key, profile, or attempt data was modified.
- This branch is for review and CI verification only. The migration history should not be repaired in Production until the pre-005 baseline and deployment sequence have been reviewed.
