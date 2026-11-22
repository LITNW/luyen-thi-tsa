-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261115154958, name=multiple_stimulus_groups
-- statement_md5=df2758e9e52489723f57272dbfa3d4d6
-- Evidence source: supabase/migrations/20261115154958_multiple_stimulus_groups.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261115154958 must never execute on a fresh database.';
end;
$staging_history_marker$;
