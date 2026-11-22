-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082751, name=20261112023553_exam_room_offline_sync_and_server_timing
-- statement_md5=1917837dea4486aef95819bdbb31759c
-- Evidence source: supabase/migrations/20261112023553_exam_room_offline_sync_and_server_timing.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082751 must never execute on a fresh database.';
end;
$staging_history_marker$;
