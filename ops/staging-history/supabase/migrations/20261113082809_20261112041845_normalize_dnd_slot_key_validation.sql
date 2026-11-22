-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082809, name=20261112041845_normalize_dnd_slot_key_validation
-- statement_md5=282c5ddb62e435cd3a58011084ee1326
-- Evidence source: supabase/migrations/20261112041845_normalize_dnd_slot_key_validation.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082809 must never execute on a fresh database.';
end;
$staging_history_marker$;
