-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113100149, name=exam_category_archived_assignment_preservation
-- statement_md5=48817e09315c0c4d25fe2cc050c4350b
-- Evidence source: supabase/migrations/20261113140000_exam_category_archived_assignment_preservation.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113100149 must never execute on a fresh database.';
end;
$staging_history_marker$;
