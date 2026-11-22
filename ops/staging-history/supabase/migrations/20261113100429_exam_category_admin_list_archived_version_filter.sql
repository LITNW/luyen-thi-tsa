-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113100429, name=exam_category_admin_list_archived_version_filter
-- statement_md5=743a3084435199f2b8afbd0631aacf40
-- Evidence source: supabase/migrations/20261113150000_exam_category_admin_list_archived_version_filter.sql
-- Classification: exact_statement_match
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113100429 must never execute on a fresh database.';
end;
$staging_history_marker$;
