-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082639, name=20261111145753_first_admin_verified_email_bootstrap
-- statement_md5=e98618c8534c8a3820d6c751e5c8f8dd
-- Evidence source: supabase/migrations/20261111145753_first_admin_verified_email_bootstrap.sql
-- Classification: environment_specific_email_redaction
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082639 must never execute on a fresh database.';
end;
$staging_history_marker$;
