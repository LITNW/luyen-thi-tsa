-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082646, name=20261111145854_student_published_exam_read_rpcs
-- statement_md5=98f03d2f5ca8ab6adc9fe87cd1b8f530
-- Evidence source: supabase/migrations/20261111145854_student_published_exam_read_rpcs.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082646 must never execute on a fresh database.';
end;
$staging_history_marker$;
