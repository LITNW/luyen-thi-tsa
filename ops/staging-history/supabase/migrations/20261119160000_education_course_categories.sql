-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261119160000, name=education_course_categories
-- statement_md5=7ead7404c9af02fe5f412b15bf1c5e75
-- Evidence source: supabase/migrations/20261119160000_education_course_categories.sql
-- Classification: remote_recorded_statement_fingerprint
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261119160000 must never execute on a fresh database.';
end;
$staging_history_marker$;
