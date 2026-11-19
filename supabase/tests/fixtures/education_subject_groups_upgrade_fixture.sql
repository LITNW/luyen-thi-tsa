-- Seed rows in the legacy schema so the following migration exercises backfill and FK preservation.
begin;

insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
values('00000000-0000-4000-8000-000000000010','course-upgrade-fixture@example.test',now(),'{"display_name":"Course Upgrade Fixture"}'::jsonb)
on conflict (id) do nothing;

insert into public.education_subjects(
  id,education_level_id,education_node_id,subject_id,local_code,display_name
)
select '69000000-0000-4000-8000-000000000010',l.id,null,s.id,'UPGRADE-UNI-1','Pre-migration university course'
from public.education_levels l cross join public.subjects s
where l.code='university' and s.code='science'
on conflict (id) do nothing;

insert into public.education_subjects(
  id,education_level_id,education_node_id,subject_id,local_code,display_name
)
select '69000000-0000-4000-8000-000000000011',l.id,null,s.id,'UPGRADE-THPT-1','Pre-migration THPT course'
from public.education_levels l cross join public.subjects s
where l.code='thpt' and s.code='science'
on conflict (id) do nothing;

insert into public.exams(id,title,description,duration_minutes,created_by,education_subject_id)
values('69000000-0000-4000-8000-000000000012','Pre-migration course exam','Disposable migration fixture',30,'00000000-0000-4000-8000-000000000010','69000000-0000-4000-8000-000000000010')
on conflict (id) do nothing;

commit;
