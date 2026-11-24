-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082746, name=20261111152717_avoid_duplicate_question_versions_on_save
-- statement_md5=e63fb05e007c1c1a4b4ba1e225124f58
-- Evidence source: supabase/migrations/20261111152717_avoid_duplicate_question_versions_on_save.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082746 must never execute on a fresh database.';
end;
$staging_history_marker$;
