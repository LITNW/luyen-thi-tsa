-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082722, name=20261111151651_attempt_resume_and_history_rpcs
-- statement_md5=0cff5c04918c0010d988cee40c59a2e4
-- Evidence source: supabase/migrations/20261111151651_attempt_resume_and_history_rpcs.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082722 must never execute on a fresh database.';
end;
$staging_history_marker$;
