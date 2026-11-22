-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261115150434, name=stimulus_rpc_invoker_hardening
-- statement_md5=dd444e963edf291a2ea3c914755025e1
-- Evidence source: supabase/migrations/20261115150434_stimulus_rpc_invoker_hardening.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261115150434 must never execute on a fresh database.';
end;
$staging_history_marker$;
