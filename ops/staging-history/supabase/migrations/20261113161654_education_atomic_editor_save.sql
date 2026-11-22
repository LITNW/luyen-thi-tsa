-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113161654, name=education_atomic_editor_save
-- statement_md5=8a421e010f8c800b1fe66b3acc2ccfe5
-- Evidence source: supabase/migrations/20261113161654_education_atomic_editor_save.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113161654 must never execute on a fresh database.';
end;
$staging_history_marker$;
