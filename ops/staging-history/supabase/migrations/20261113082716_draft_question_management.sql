-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082716, name=20261111151520_draft_question_management
-- statement_md5=b1bc147d1cbde86b6f0e2dc46731cc54
-- Evidence source: supabase/migrations/20261111151520_draft_question_management.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082716 must never execute on a fresh database.';
end;
$staging_history_marker$;
