-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113155356, name=education_hierarchy_active_profile_read_policies
-- statement_md5=caab9ce5ac5d855cc6c6463b87e0cf68
-- Evidence source: supabase/migrations/20261113155356_education_hierarchy_active_profile_read_policies.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113155356 must never execute on a fresh database.';
end;
$staging_history_marker$;
