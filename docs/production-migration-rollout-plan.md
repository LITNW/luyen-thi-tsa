# Production migration rollout plan — PR #40

Status: prepared, not executed. Snapshot date: 2026-11-19.

## 1. Hard safety boundary

This document is a runbook only. No hosted migration, DDL, DML, migration repair, deployment, or PR merge was performed while preparing it.

Production must remain unchanged until a separate rollout approval is given. Do not merge PR #40 as part of this preparation.

## 2. Verified starting state

Production project: `hwqtsopvpucadgpkigqz`

- PostgreSQL 17.11.0.018.
- Migration ledger: 31 rows; latest version `20261116033119`.
- `public.question_versions.stimulus_version_id`: absent.
- `public.question_version_stimuli`: absent.
- Storage bucket `lit-question-media`: absent.
- `public.admin_delete_exam_version(uuid)` still has the old physical-delete body (definition MD5 `539db26c22e2e4e310cc3a217b15f8f0`).
- `authenticated` does not have EXECUTE on `public.admin_delete_exam_version(uuid)`.
- `public.get_published_exam(uuid)` still lacks the archived-at filter (definition MD5 `7ea0eca5331c7e60682dc4af7c82a4d3`).

Staging project: `cppalwtdkditlhojpeyc`

- PostgreSQL 17.11.0.019.
- Migration ledger: 38 rows; latest version `20261118032350`.
- Media/stimulus objects and archived-exam guards are present.
- `admin_delete_exam_version` is archive-only and writes an audit record.
- `authenticated` retains EXECUTE on the archive RPC.

The Production values above were re-queried after repository work and match the pre-work snapshot. No hosted database was changed.

## 3. Backup prerequisites

The PostgreSQL backup/restore drill passed on 2026-11-19:

- Custom-format dump: 740,230 bytes.
- Archive listing: 815 entries.
- Local isolated restore: 67 tables and 31 migration rows.
- SHA-256: `5A3AF5539B3515BB307BA8B994571BC39EA43F563B19B39F6D8434DCF9850024`.

This dump does **not** contain the binary payloads of Supabase Storage objects. Before Production rollout, create a separate Storage-object backup for every bucket, including object paths and metadata, and verify that representative files can be restored. Do not treat the PostgreSQL dump as a complete Supabase backup.

## 4. Migration sequence pending on Production

The following shared migrations are already recorded on Staging but not Production. Apply only after the dry-run and migration-history checks below are clean:

1. `20261115150336_question_media_stimulus_groups.sql`
2. `20261115150434_stimulus_rpc_invoker_hardening.sql`
3. `20261115150559_question_media_validator_grants.sql`
4. `20261115154958_multiple_stimulus_groups.sql`
5. `20261116033209_archive_exam_versions_without_physical_deletion.sql`
6. `20261118032350_exclude_archived_exam_media.sql`

The archive-only migration uses `CREATE OR REPLACE FUNCTION` and intentionally has no GRANT/REVOKE. PostgreSQL preserves the existing ACL. Consequently, Production's authenticated EXECUTE revocation remains in force after this migration.

### Environment-specific migrations

- Production-only `20261116033119_temporarily_revoke_authenticated_exam_version_delete` is already in the Production ledger. Preserve its revocation. Do not replay or reverse it.
- Staging-only `20261113090912_staging_auth_profile_display_name_fallback` changes signup behavior. Do not promote it to Production as part of PR #40.
- Staging's reconstructed baseline and re-recorded recovery versions are not original Production migration versions. Do not run `migration repair` merely to make the ledgers' version strings match.
- The two category follow-up migrations have different version strings in Staging and Production, but the relevant live function fingerprints currently match.

## 5. Mandatory preflight before any write

1. Confirm a fresh Production database dump and Storage-object backup exist, are checksummed, and have a verified restore path.
2. Run `supabase migration list` against Production and Staging and save the outputs.
3. Run `supabase db push --dry-run` against Production only after confirming the linked project ref is `hwqtsopvpucadgpkigqz`.
4. Inspect every pending migration in the dry-run output. The expected shared pending set is exactly the six migrations listed above.
5. If the CLI reports a remote-only version, out-of-order migration, unexpected pending migration, or any proposed operation outside this set, STOP. Do not run `supabase migration repair` or a real `db push` until the environment-specific ledger handling is separately resolved and approved.
6. Confirm PR #40 still passes all required CI and preview checks and remains Draft until the rollout approval.

## 6. Expected post-migration verification

Run read-only checks against Production and compare the results with the migration sources:

- `question_versions.stimulus_version_id` exists.
- `question_version_stimuli` exists with RLS enabled and no direct client grants/policies; its write path remains trigger-only.
- `lit-question-media` exists and is private.
- The four media/stimulus migrations' triggers, validator functions, RPC grants, and Storage policies match their reviewed SQL.
- `admin_delete_exam_version(uuid)` is archive-only, emits `exam_version.archive` audit records, and does not physically delete attempts or question mappings.
- `has_function_privilege('authenticated','public.admin_delete_exam_version(uuid)','EXECUTE')` remains **false** unless a separate approval explicitly changes the Production-only hotfix.
- `get_published_exam(uuid)` and `private.lit_can_read_question_media(text)` both exclude archived exam versions.
- Production migration ledger contains the six shared migrations with no unexplained version drift.

The authenticated archive RPC will remain unavailable to the Admin client while the Production EXECUTE revocation is retained. If the product requires Admins to invoke archive through the authenticated client, that is a separate access-control decision and must not be silently bundled into this rollout.

## 7. Application smoke tests after the database gate

Only after the migration rollout is separately approved:

- Admin upload of an allowed image type and rejection of disallowed/oversized media.
- Student access to assets referenced by a published question.
- Denial of media access for unpublished or archived exam versions.
- Multi-stimulus rendering and ordering across an exam version.
- Existing exam start, answer save, submit, result, and history flows.
- Admin authoring and category/education selectors.
- Confirm analytics remains disabled and no consent/under-16 policy gates are bypassed.

## 8. Stop conditions

Stop before any write if backup/restore checksums differ, Storage backup is incomplete, dry-run migration set differs from the six expected migrations, Production-only ACL revocation would be altered, or any migration/test fails. Do not merge PR #40 or deploy the application until these conditions are resolved and separately approved.
