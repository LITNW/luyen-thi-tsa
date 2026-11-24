-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261115150336, name=question_media_stimulus_groups
-- statement_md5=7c837a16599da4782a81fb3c768363cb
-- Evidence source: supabase/migrations/20261115150336_question_media_stimulus_groups.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261115150336 must never execute on a fresh database.';
end;
$staging_history_marker$;
