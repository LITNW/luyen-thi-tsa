-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082650, name=20261111145919_consolidate_profile_update_policy
-- statement_md5=8f19a67c4ba1cb76500d6bb23138d437
-- Evidence source: supabase/migrations/20261111145919_consolidate_profile_update_policy.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082650 must never execute on a fresh database.';
end;
$staging_history_marker$;
