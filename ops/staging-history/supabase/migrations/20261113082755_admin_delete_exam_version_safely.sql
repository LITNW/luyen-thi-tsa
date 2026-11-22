-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082755, name=20261112023833_admin_delete_exam_version_safely
-- statement_md5=09a37eea4291a7e1ae86ab5d5b8fcd3b
-- Evidence source: supabase/migrations/20261112023833_admin_delete_exam_version_safely.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082755 must never execute on a fresh database.';
end;
$staging_history_marker$;
