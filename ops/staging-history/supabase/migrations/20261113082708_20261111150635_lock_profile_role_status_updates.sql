-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082708, name=20261111150635_lock_profile_role_status_updates
-- statement_md5=ae9de7d4fe246ab3062b4eb770393744
-- Evidence source: supabase/migrations/20261111150635_lock_profile_role_status_updates.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082708 must never execute on a fresh database.';
end;
$staging_history_marker$;
