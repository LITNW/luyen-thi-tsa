-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113155228, name=education_hierarchy_foundation
-- statement_md5=fa1f4117e8ba0ad72463a3876063d042
-- Evidence source: supabase/migrations/20261113155228_education_hierarchy_foundation.sql
-- Classification: equivalent_condition_syntax
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113155228 must never execute on a fresh database.';
end;
$staging_history_marker$;
