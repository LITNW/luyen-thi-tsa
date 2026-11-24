-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113155742, name=education_hierarchy_identity_guards
-- statement_md5=2d2cb1f9fcfb3b83e676034da0950af7
-- Evidence source: supabase/migrations/20261113155742_education_hierarchy_identity_guards.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113155742 must never execute on a fresh database.';
end;
$staging_history_marker$;
