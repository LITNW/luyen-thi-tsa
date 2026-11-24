-- STAGING HISTORY MARKER ONLY — DO NOT EXECUTE.
-- Already applied on Staging project cppalwtdkditlhojpeyc.
-- Remote ledger: version=20261118032350, name=exclude_archived_exam_media
-- statement_md5=7487f0f74fe93dbdae0c28fb29d2edd2
-- Evidence source: supabase/migrations/20261118032350_exclude_archived_exam_media.sql
-- Classification: comments_only
-- This guard intentionally fails if the marker is ever treated as pending.

do $staging_history_marker$
begin
  raise exception 'Staging history marker 20261118032350 must never execute on a fresh database.';
end;
$staging_history_marker$;
