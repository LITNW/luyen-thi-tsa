# Existing Staging migration-history adapter

**Staging only. Existing database only. Not a clean-install chain.**

Project ref: `cppalwtdkditlhojpeyc`.

The Staging database was reconstructed from a pre-005 public-schema baseline and has 38 migration-ledger rows with environment-specific version timestamps. The root `supabase/migrations` directory remains the canonical chain for clean installs and Production.

This adapter provides local marker files for the 38 versions already present in the existing Staging ledger. Every marker intentionally raises an exception if executed. They exist only so Supabase CLI can recognize those already-applied remote versions. If any marker appears in a dry-run pending list, STOP. Never run this adapter against a fresh database, local reset, Preview branch, or Production.

Before using the adapter:
1. Run `preflight.sql` read-only against Staging. The mismatch query must return zero rows and the ledger count must be exactly 38.
2. Verify the category table and `education_subjects.category_id` are absent and the obsolete temporary write-freeze policies are absent.
3. Use Supabase CLI 3.2.0 and explicitly target the Staging project ref.

Validate the adapter config before the database preflight; this command is local-only and does not contact Supabase:

```powershell
supabase config validate --workdir ops/staging-history
```

PowerShell example:

```powershell
$env:SUPABASE_WORKDIR = "ops/staging-history"
supabase db push --remote=cppalwtdkditlhojpeyc --dry-run
```

The dry-run must list exactly one pending migration:
`20261119160000_education_course_categories.sql`.

Only after the read-only preflight and dry-run both pass may the approved Staging migration be applied:

```powershell
supabase db push --remote=cppalwtdkditlhojpeyc
```

Never use `--include-all`, `migration repair`, manual ledger edits, or this adapter against Production. If the ledger differs from this manifest, stop and re-investigate; do not regenerate the manifest from an unexplained live state.
