-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082827, name=20261113100000_m1_subject_taxonomy_stimuli
-- statement_md5=426db8103b54d9da96ce5a42602e8694
-- Evidence source: supabase/migrations/20261113100000_m1_subject_taxonomy_stimuli.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082827 must never execute on a fresh database.';
end;
$staging_history_marker$;
