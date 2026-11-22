-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082816, name=20261112170000_centralize_exam_answer_validation
-- statement_md5=ead927df45920c9e9b4d54363ae8edf1
-- Evidence source: supabase/migrations/20261112170000_centralize_exam_answer_validation.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082816 must never execute on a fresh database.';
end;
$staging_history_marker$;
