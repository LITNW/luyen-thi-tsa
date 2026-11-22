-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113160130, name=education_exam_placement_and_scoped_catalogue
-- statement_md5=4de3b752169f3fb5a83d9e6f68dcf71f
-- Evidence source: supabase/migrations/20261113160130_education_exam_placement_and_scoped_catalogue.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113160130 must never execute on a fresh database.';
end;
$staging_history_marker$;
