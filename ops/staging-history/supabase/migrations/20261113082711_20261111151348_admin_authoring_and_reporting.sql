-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082711, name=20261111151348_admin_authoring_and_reporting
-- statement_md5=f0356c358fba9ce5cc6430f1e187cb7b
-- Evidence source: supabase/migrations/20261111151348_admin_authoring_and_reporting.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082711 must never execute on a fresh database.';
end;
$staging_history_marker$;
