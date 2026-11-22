-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082742, name=20261111152621_enforce_active_attempt_owner
-- statement_md5=8751535c337cc71f6f5c0622200fd4c5
-- Evidence source: supabase/migrations/20261111152621_enforce_active_attempt_owner.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082742 must never execute on a fresh database.';
end;
$staging_history_marker$;
