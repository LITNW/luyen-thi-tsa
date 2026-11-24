-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082812, name=20261112050000_ai_exam_import_staging
-- statement_md5=53435802a6c75d710dc8a269924b8d39
-- Evidence source: supabase/migrations/20261112050000_ai_exam_import_staging.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082812 must never execute on a fresh database.';
end;
$staging_history_marker$;
