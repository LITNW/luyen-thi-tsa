-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261114024035, name=education_exam_version_publish_guard
-- statement_md5=be84b0672d33ac74eefa0d57d0c7b84c
-- Evidence source: supabase/migrations/20261114024035_education_exam_version_publish_guard.sql
-- Classification: trailing_newline_only
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261114024035 must never execute on a fresh database.';
end;
$staging_history_marker$;
