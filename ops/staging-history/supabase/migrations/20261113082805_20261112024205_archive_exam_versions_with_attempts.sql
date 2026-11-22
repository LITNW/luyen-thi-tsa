-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082805, name=20261112024205_archive_exam_versions_with_attempts
-- statement_md5=184bcd2eff24f194ebe1edf787c10413
-- Evidence source: supabase/migrations/20261112024205_archive_exam_versions_with_attempts.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082805 must never execute on a fresh database.';
end;
$staging_history_marker$;
