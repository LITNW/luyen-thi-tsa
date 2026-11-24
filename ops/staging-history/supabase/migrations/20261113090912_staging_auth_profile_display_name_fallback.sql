-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113090912, name=staging_auth_profile_display_name_fallback
-- statement_md5=58aab26f7158e84dc77bf2a63e841778
-- Evidence source: supabase/ops/staging/20261113090912_staging_auth_profile_display_name_fallback.sql
-- Classification: staging_only_environment_migration
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113090912 must never execute on a fresh database.';
end;
$staging_history_marker$;
