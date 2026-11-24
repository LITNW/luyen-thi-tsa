-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082626, name=staging_pre_005_reconstructed_baseline
-- statement_md5=1114124a5836dff5e78883902f87709d
-- Evidence source: supabase/tests/fixtures/pre_005_supabase_schema.sql
-- Classification: reconstructed_baseline_exact_fixture
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082626 must never execute on a fresh database.';
end;
$staging_history_marker$;
