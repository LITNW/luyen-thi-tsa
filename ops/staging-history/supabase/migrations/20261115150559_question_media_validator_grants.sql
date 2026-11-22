-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261115150559, name=question_media_validator_grants
-- statement_md5=80dee34e0d3671f4873222868eb6afb2
-- Evidence source: supabase/migrations/20261115150559_question_media_validator_grants.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261115150559 must never execute on a fresh database.';
end;
$staging_history_marker$;
