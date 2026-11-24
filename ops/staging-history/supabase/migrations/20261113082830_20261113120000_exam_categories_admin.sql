-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261113082830, name=20261113120000_exam_categories_admin
-- statement_md5=ceb823b7f9f88787dfd4e50d6f848acf
-- Evidence source: supabase/migrations/20261113120000_exam_categories_admin.sql + supabase/migrations/20261113140000_exam_category_archived_assignment_preservation.sql
-- Classification: base_migration_contains_followup_behavior
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261113082830 must never execute on a fresh database.';
end;
$staging_history_marker$;
