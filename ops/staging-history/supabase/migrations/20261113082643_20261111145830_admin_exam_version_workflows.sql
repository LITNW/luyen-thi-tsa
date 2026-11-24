-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082643, name=20261111145830_admin_exam_version_workflows
-- statement_md5=739f560fa09fd011ae1cda72433586a5
-- Evidence source: supabase/migrations/20261111145830_admin_exam_version_workflows.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082643 must never execute on a fresh database.';
end;
$staging_history_marker$;
