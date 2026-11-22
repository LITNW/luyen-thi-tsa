-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261116033209, name=archive_exam_versions_without_physical_deletion
-- statement_md5=af047b7d66c69899175735f974fe7ff8
-- Evidence source: supabase/migrations/20261116033209_archive_exam_versions_without_physical_deletion.sql
-- Classification: equivalent_function_serialization
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261116033209 must never execute on a fresh database.';
end;
$staging_history_marker$;
