-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082728, name=20261111151737_atomic_exam_authoring
-- statement_md5=9d046c27786ffac565a37fd85145e851
-- Evidence source: supabase/migrations/20261111151737_atomic_exam_authoring.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082728 must never execute on a fresh database.';
end;
$staging_history_marker$;
