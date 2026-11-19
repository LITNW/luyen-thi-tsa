# Supabase migration drift reconciliation

Snapshot verified read-only on 2026-11-19.

## Live ledger overview

| Environment | Project ref | Ledger rows | PostgreSQL |
|---|---|---:|---|
| Staging | `cppalwtdkditlhojpeyc` | 38 | 17.11.0.019 |
| Production | `hwqtsopvpucadgpkigqz` | 31 | 17.11.0.018 |

The row-count difference is not a simple set of seven missing migrations.

Staging has a reconstructed baseline row (`20261113082626_staging_pre_005_reconstructed_baseline`) and re-recorded versions of the 17 recovered Production migrations. Those Staging ledger versions are in the `202611130826xx` range; their names retain the original Production migration timestamps. The Git migration files and recovery manifest retain the original Production versions. Do not repair or rewrite either hosted ledger merely to make the version strings match.

The two exam-category follow-up migrations use different ledger versions in the environments:
- Staging `20261113100149` vs Production `20261113140000`
- Staging `20261113100429` vs Production `20261113150000`

The live function-definition fingerprints match across environments for `admin_get_exam_version`, `admin_list_exam_categories`, `admin_list_exam_versions`, and `admin_save_exam_content_with_education`. Treat these as ledger-version/statement-serialization differences, not demonstrated live behavior drift.

## Shared migrations present on Staging and pending on Production

The following migrations are recorded in Staging but absent from Production:
- `20261115150336_question_media_stimulus_groups`
- `20261115150434_stimulus_rpc_invoker_hardening`
- `20261115150559_question_media_validator_grants`
- `20261115154958_multiple_stimulus_groups`
- `20261116033209_archive_exam_versions_without_physical_deletion`
- `20261118032350_exclude_archived_exam_media`

The first four implement private question media and version-pinned stimulus groups. The fifth replaces the legacy exam-version deletion RPC with an archive-only operation and an atomic audit record. The sixth blocks archived exam versions from the published-exam payload and private-media authorization paths.

The archive-only migration is now represented in the active migration directory as `supabase/migrations/20261116033209_archive_exam_versions_without_physical_deletion.sql`. It deliberately contains no GRANT or REVOKE statement. PostgreSQL `CREATE OR REPLACE FUNCTION` preserves the function ACL, so applying it does not undo Production's separately recorded authenticated EXECUTE revocation.

## Environment-specific SQL; not active migrations

### Production-only privilege hotfix

Production records `20261116033119_temporarily_revoke_authenticated_exam_version_delete` with statement MD5 `d5d97874e0ce49a188a5a539664229f2`. It revokes EXECUTE on `public.admin_delete_exam_version(uuid)` from `authenticated`. The current Production ACL confirms that `authenticated` is absent while `service_role` retains EXECUTE.

An evidence copy is stored at `supabase/ops/production/20261116033119_temporarily_revoke_authenticated_exam_version_delete.sql`. Keep this operational hotfix intact. Do not add it to the shared migration chain or grant the privilege back as part of this reconciliation.

### Staging-only signup fallback

Staging records `20261113090912_staging_auth_profile_display_name_fallback` with statement MD5 `58aab26f7158e84dc77bf2a63e841778`. It changes `public.handle_new_auth_user()` to derive a missing display name from the email local-part. Production's current function still rejects a missing display name.

An evidence copy is stored at `supabase/ops/staging/20261113090912_staging_auth_profile_display_name_fallback.sql`. This is intentionally not promoted to Production by this PR: it changes signup behavior and needs a separate product/privacy decision.

## Current live object parity observations

- `public.question_version_stimuli`, `question_versions.stimulus_version_id`, private bucket `lit-question-media`, associated storage policies/triggers, and archived-exam media guards exist on Staging and are absent on Production.
- `public.get_published_exam(uuid)` on Staging rejects `exam_versions.archived_at IS NOT NULL`; Production's current definition does not yet apply that predicate.
- Staging's `admin_delete_exam_version(uuid)` is archive-only, writes `exam_version.archive` to `audit_logs`, and retains attempts/mappings. Production's current function still has a physical-delete path when no attempt exists, but authenticated EXECUTE is revoked by the Production-only hotfix.
- The shared archive-only migration does not modify function ACLs. It is designed to preserve the current environment-specific ACL when applied.

## Safety and rollout boundary

This reconciliation changes repository files and CI only. It does not run `supabase db push`, `migration repair`, SQL migrations, DDL, or DML against either hosted project. Production and Staging remain read-only.

Do not merge PR #40 or deploy Production as part of this work. After repository CI passes, a separate rollout plan must sequence the pending shared migrations against a fresh backup and the verified local restore. Supabase Storage object bytes require a separate backup plan; the PostgreSQL dump alone does not contain those object payloads.
