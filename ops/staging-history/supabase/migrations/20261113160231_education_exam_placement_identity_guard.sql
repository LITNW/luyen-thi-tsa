-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113160231, name=education_exam_placement_identity_guard
-- statement_md5=71273dc9ccafdcaffc3cb5bbc5ac9df0
-- Evidence source: supabase/migrations/20261113160231_education_exam_placement_identity_guard.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113160231 must never execute on a fresh database.';
end;
$staging_history_marker$;
