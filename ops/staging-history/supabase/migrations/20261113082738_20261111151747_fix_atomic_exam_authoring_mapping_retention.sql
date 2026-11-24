-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082738, name=20261111151747_fix_atomic_exam_authoring_mapping_retention
-- statement_md5=47d906af8e7f99f19751f4f4dd6fdfc4
-- Evidence source: supabase/migrations/20261111151747_fix_atomic_exam_authoring_mapping_retention.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082738 must never execute on a fresh database.';
end;
$staging_history_marker$;
