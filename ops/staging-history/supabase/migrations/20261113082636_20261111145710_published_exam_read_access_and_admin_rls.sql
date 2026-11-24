-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082636, name=20261111145710_published_exam_read_access_and_admin_rls
-- statement_md5=fa53a74371b39dc54b823f34b6f11017
-- Evidence source: supabase/migrations/20261111145710_published_exam_read_access_and_admin_rls.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082636 must never execute on a fresh database.';
end;
$staging_history_marker$;
