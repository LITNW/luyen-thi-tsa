-- READ-ONLY preflight for the existing Staging migration ledger.
-- Expected values were captured from project cppalwtdkditlhojpeyc on 2026-11-22.
-- Zero rows from the first query and row_count_matches=true are required before db push.

with expected(version,name,statement_md5) as (
  values
    ('20261113082626','staging_pre_005_reconstructed_baseline','1114124a5836dff5e78883902f87709d'),
    ('20261113082636','20261111145710_published_exam_read_access_and_admin_rls','fa53a74371b39dc54b823f34b6f11017'),
    ('20261113082639','20261111145753_first_admin_verified_email_bootstrap','e98618c8534c8a3820d6c751e5c8f8dd'),
    ('20261113082643','20261111145830_admin_exam_version_workflows','739f560fa09fd011ae1cda72433586a5'),
    ('20261113082646','20261111145854_student_published_exam_read_rpcs','98f03d2f5ca8ab6adc9fe87cd1b8f530'),
    ('20261113082650','20261111145919_consolidate_profile_update_policy','8f19a67c4ba1cb76500d6bb23138d437'),
    ('20261113082708','20261111150635_lock_profile_role_status_updates','ae9de7d4fe246ab3062b4eb770393744'),
    ('20261113082711','20261111151348_admin_authoring_and_reporting','f0356c358fba9ce5cc6430f1e187cb7b'),
    ('20261113082716','20261111151520_draft_question_management','b1bc147d1cbde86b6f0e2dc46731cc54'),
    ('20261113082722','20261111151651_attempt_resume_and_history_rpcs','0cff5c04918c0010d988cee40c59a2e4'),
    ('20261113082728','20261111151737_atomic_exam_authoring','9d046c27786ffac565a37fd85145e851'),
    ('20261113082738','20261111151747_fix_atomic_exam_authoring_mapping_retention','47d906af8e7f99f19751f4f4dd6fdfc4'),
    ('20261113082742','20261111152621_enforce_active_attempt_owner','8751535c337cc71f6f5c0622200fd4c5'),
    ('20261113082746','20261111152717_avoid_duplicate_question_versions_on_save','e63fb05e007c1c1a4b4ba1e225124f58'),
    ('20261113082751','20261112023553_exam_room_offline_sync_and_server_timing','1917837dea4486aef95819bdbb31759c'),
    ('20261113082755','20261112023833_admin_delete_exam_version_safely','09a37eea4291a7e1ae86ab5d5b8fcd3b'),
    ('20261113082805','20261112024205_archive_exam_versions_with_attempts','184bcd2eff24f194ebe1edf787c10413'),
    ('20261113082809','20261112041845_normalize_dnd_slot_key_validation','282c5ddb62e435cd3a58011084ee1326'),
    ('20261113082812','20261112050000_ai_exam_import_staging','53435802a6c75d710dc8a269924b8d39'),
    ('20261113082816','20261112170000_centralize_exam_answer_validation','ead927df45920c9e9b4d54363ae8edf1'),
    ('20261113082827','20261113100000_m1_subject_taxonomy_stimuli','426db8103b54d9da96ce5a42602e8694'),
    ('20261113082830','20261113120000_exam_categories_admin','ceb823b7f9f88787dfd4e50d6f848acf'),
    ('20261113090912','staging_auth_profile_display_name_fallback','58aab26f7158e84dc77bf2a63e841778'),
    ('20261113100149','exam_category_archived_assignment_preservation','48817e09315c0c4d25fe2cc050c4350b'),
    ('20261113100429','exam_category_admin_list_archived_version_filter','743a3084435199f2b8afbd0631aacf40'),
    ('20261113155228','education_hierarchy_foundation','fa1f4117e8ba0ad72463a3876063d042'),
    ('20261113155356','education_hierarchy_active_profile_read_policies','caab9ce5ac5d855cc6c6463b87e0cf68'),
    ('20261113155742','education_hierarchy_identity_guards','2d2cb1f9fcfb3b83e676034da0950af7'),
    ('20261113160130','education_exam_placement_and_scoped_catalogue','4de3b752169f3fb5a83d9e6f68dcf71f'),
    ('20261113160231','education_exam_placement_identity_guard','71273dc9ccafdcaffc3cb5bbc5ac9df0'),
    ('20261113161654','education_atomic_editor_save','8a421e010f8c800b1fe66b3acc2ccfe5'),
    ('20261114024035','education_exam_version_publish_guard','be84b0672d33ac74eefa0d57d0c7b84c'),
    ('20261115150336','question_media_stimulus_groups','7c837a16599da4782a81fb3c768363cb'),
    ('20261115150434','stimulus_rpc_invoker_hardening','dd444e963edf291a2ea3c914755025e1'),
    ('20261115150559','question_media_validator_grants','80dee34e0d3671f4873222868eb6afb2'),
    ('20261115154958','multiple_stimulus_groups','df2758e9e52489723f57272dbfa3d4d6'),
    ('20261116033209','archive_exam_versions_without_physical_deletion','af047b7d66c69899175735f974fe7ff8'),
    ('20261118032350','exclude_archived_exam_media','7487f0f74fe93dbdae0c28fb29d2edd2')
),
actual as (
  select version,name,md5(coalesce(statements[1],'')) as statement_md5
  from supabase_migrations.schema_migrations
)
select
  coalesce(e.version,a.version) as version,
  e.name as expected_name,
  a.name as actual_name,
  e.statement_md5 as expected_statement_md5,
  a.statement_md5 as actual_statement_md5
from expected e
full outer join actual a using(version)
where e.version is null
   or a.version is null
   or e.name is distinct from a.name
   or e.statement_md5 is distinct from a.statement_md5
order by 1;

select count(*) as actual_ledger_rows,
       38::integer as expected_ledger_rows,
       count(*)=38 as row_count_matches
from supabase_migrations.schema_migrations;

-- Confirm the category migration has not already been partially applied.
select
  to_regclass('public.education_course_categories') as category_table,
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='education_subjects' and column_name='category_id'
  ) as category_id_column,
  exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='education_subjects'
      and policyname in ('staging_pause_university_course_insert','staging_pause_university_course_update')
  ) as obsolete_write_freeze_exists;
