-- Run after 20261119160000_education_subject_groups.sql in a disposable database.
begin;

do $assert$
declare
  v_thpt uuid;
  v_university uuid;
  v_group uuid;
  v_thpt_course uuid;
  v_course uuid;
  v_wrong_group uuid;
  v_exam uuid := '69000000-0000-4000-8000-000000000001';
  v_editor_result jsonb;
  v_editor_exam uuid;
  v_editor_version uuid;
  v_questions jsonb := '[
    {
      "mapping_id": null,
      "question_id": null,
      "scope": "exam",
      "owner_exam_id": null,
      "type": "mc",
      "content": {"q":"1 + 1 = ?","o":["1","2"]},
      "answer_key": 1,
      "explanation": "Phép cộng cơ bản.",
      "grading_config": {},
      "source_metadata": {},
      "points": 1
    }
  ]'::jsonb;
begin
  select id into v_thpt from public.education_levels where code='thpt';
  select id into v_university from public.education_levels where code='university';
  if v_thpt is null or v_university is null then raise exception 'Expected seeded education levels.'; end if;
  if (select count(*) from public.education_subject_groups where education_level_id=v_university) < 6 then
    raise exception 'Expected all six default university groups.';
  end if;
  if exists (select 1 from public.education_subjects es join public.education_levels l on l.id=es.education_level_id where l.code='university' and es.group_id is null) then
    raise exception 'Existing university courses must be assigned to a valid group.';
  end if;
  if exists (select 1 from public.education_subjects es join public.education_levels l on l.id=es.education_level_id where l.code='thpt' and es.group_id is not null) then
    raise exception 'THPT courses must remain ungrouped.';
  end if;
  if not exists (
    select 1 from public.education_subjects es join public.education_levels l on l.id=es.education_level_id
    where es.id='69000000-0000-4000-8000-000000000010' and l.code='university' and es.group_id is not null
      and es.group_id=(select id from public.education_subject_groups where education_level_id=v_university and code='unclassified')
  ) then raise exception 'Pre-migration university course was not preserved and backfilled to unclassified.'; end if;
  if not exists (
    select 1 from public.education_subjects es join public.education_levels l on l.id=es.education_level_id
    where es.id='69000000-0000-4000-8000-000000000011' and l.code='thpt' and es.group_id is null
  ) then raise exception 'Pre-migration THPT course was not preserved as a direct course.'; end if;
  if (select education_subject_id from public.exams where id='69000000-0000-4000-8000-000000000012') is distinct from '69000000-0000-4000-8000-000000000010'::uuid then
    raise exception 'Pre-migration exam-to-course reference changed during backfill.';
  end if;
  select id into v_group from public.education_subject_groups where education_level_id=v_university and code='unclassified';
  select id into v_wrong_group from public.education_subject_groups where education_level_id=v_university and code='general_sciences';
  insert into public.education_subjects(education_level_id,display_name,local_code)
    values(v_thpt,'Direct THPT course','TEST-THPT-1') returning id into v_thpt_course;
  if not exists (select 1 from public.education_subjects where id=v_thpt_course and group_id is null) then
    raise exception 'THPT course creation must leave group_id NULL.';
  end if;
  insert into public.education_subjects(education_level_id,group_id,local_code,display_name)
    values(v_university,v_group,'TEST-GROUP-1','Group regression course') returning id into v_course;
  insert into public.exams(id,title,description,duration_minutes,created_by,education_subject_id)
    values(v_exam,'Course group regression','Disposable fixture',30,'00000000-0000-4000-8000-000000000001',v_course);
  update public.education_subjects set group_id=v_wrong_group where id=v_course;
  if not exists (select 1 from public.education_subjects where id=v_course and group_id=v_wrong_group and subject_id is null)
     or (select education_subject_id from public.exams where id=v_exam) is distinct from v_course then
    raise exception 'Moving a course must preserve its ID, nullable catalogue link, and exam reference.';
  end if;
  v_group := v_wrong_group;
  begin
    insert into public.education_subjects(education_level_id,display_name) values(v_university,'Missing university group');
    raise exception 'University course without a group was accepted.';
  exception when check_violation then null;
  end;
  begin
    delete from public.education_subject_groups where id=v_group;
    raise exception 'Course group with a dependent course was deleted.';
  exception when foreign_key_violation then null;
  end;
  begin
    update public.education_subject_groups set is_active=false where id=v_group;
    raise exception 'Group containing an active course was deactivated.';
  exception when check_violation then null;
  end;
  begin
    insert into public.education_subjects(education_level_id,group_id,display_name) values(v_thpt,v_group,'Invalid cross-level course');
    raise exception 'Cross-level group assignment was accepted.';
  exception when foreign_key_violation or check_violation then null;
  end;
  update public.education_subjects set is_active=false where id=v_course;
  update public.education_subject_groups set is_active=false where id=v_group;
  if not exists (select 1 from public.education_subjects where id=v_course and group_id=v_group and subject_id is null)
     or (select education_subject_id from public.exams where id=v_exam) is distinct from v_course then
    raise exception 'Course identity or group assignment changed unexpectedly.';
  end if;
  begin
    insert into public.education_subject_groups(education_level_id,code,name) values(v_university,'unclassified','Duplicate unclassified group');
    raise exception 'Duplicate default group code was accepted.';
  exception when unique_violation then null;
  end;
  insert into public.education_subject_groups(education_level_id,code,name,display_order)
    values(v_university,'unclassified','Chưa phân loại',6)
    on conflict (education_level_id,code) do update set name=excluded.name,display_order=excluded.display_order;
  if (select count(*) from public.education_subject_groups where education_level_id=v_university and code='unclassified') <> 1 then
    raise exception 'Idempotent default seeding created a duplicate group.';
  end if;
  update public.education_subject_groups set is_active=true where id=v_group;
  update public.education_subjects set is_active=true where id=v_course;

  -- Cover the editor RPC with a newly grouped University course, then edit its draft.
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
  v_editor_result := public.admin_save_exam_content_with_education(
    null,'University group editor draft','Regression fixture',30,v_questions,v_course,null,false
  );
  v_editor_exam := (v_editor_result->>'exam_id')::uuid;
  v_editor_version := (v_editor_result->>'exam_version_id')::uuid;
  if (select education_subject_id from public.exams where id=v_editor_exam) is distinct from v_course then
    raise exception 'University exam creation did not persist the concrete course reference.';
  end if;
  v_editor_result := public.admin_save_exam_content_with_education(
    v_editor_version,'University group editor edited','Regression fixture',30,v_questions,v_course,null,false
  );
  if (v_editor_result->>'exam_id')::uuid is distinct from v_editor_exam
     or (select education_subject_id from public.exams where id=v_editor_exam) is distinct from v_course then
    raise exception 'University exam editing changed the exam identity or concrete course reference.';
  end if;

  -- Exercise table RLS using actual database roles and auth.uid() claims.
  insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
  values
    ('00000000-0000-4000-8000-000000000004','groups-active@example.test',now(),'{"display_name":"Groups Active"}'::jsonb),
    ('00000000-0000-4000-8000-000000000005','groups-suspended@example.test',now(),'{"display_name":"Groups Suspended"}'::jsonb);
  update public.profiles set role='student',status='active' where id='00000000-0000-4000-8000-000000000004';
  update public.profiles set role='student',status='suspended' where id='00000000-0000-4000-8000-000000000005';
end;
$assert$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',true);
do $active_profile_rls$
declare
  v_groups integer;
  v_levels integer;
  v_courses integer;
begin
  select count(*) into v_groups from public.education_subject_groups;
  select count(*) into v_levels from public.education_levels;
  select count(*) into v_courses from public.education_subjects;
  if v_groups < 6 or v_levels < 2 or v_courses < 1 then
    raise exception 'Active profile should read active groups, levels, and courses; got %, %, %.',v_groups,v_levels,v_courses;
  end if;
end;
$active_profile_rls$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000005',true);
do $suspended_profile_rls$
declare
  v_groups integer;
  v_levels integer;
  v_courses integer;
begin
  select count(*) into v_groups from public.education_subject_groups;
  select count(*) into v_levels from public.education_levels;
  select count(*) into v_courses from public.education_subjects;
  if v_groups <> 0 or v_levels <> 0 or v_courses <> 0 then
    raise exception 'Suspended profile must not read education groups, levels, or courses; got %, %, %.',v_groups,v_levels,v_courses;
  end if;
end;
$suspended_profile_rls$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $admin_group_rls$
declare
  v_admin_group uuid;
  v_inactive_group_count integer;
begin
  insert into public.education_subject_groups(education_level_id,code,name)
  select id,'rls_admin_only','RLS Admin Only' from public.education_levels where code='university'
  returning id into v_admin_group;
  update public.education_subject_groups set is_active=false where id=v_admin_group;
  select count(*) into v_inactive_group_count from public.education_subject_groups where id=v_admin_group;
  if v_inactive_group_count <> 1 then
    raise exception 'Active Admin must retain access to inactive groups and group management.';
  end if;
end;
$admin_group_rls$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',true);
do $active_group_filter_rls$
begin
  if exists (select 1 from public.education_subject_groups where code='rls_admin_only') then
    raise exception 'Active non-Admin profile unexpectedly read an inactive group.';
  end if;
end;
$active_group_filter_rls$;
reset role;

-- The runbook's restrictive policies pause only University course INSERT/UPDATE writes.
create policy staging_pause_university_course_insert
on public.education_subjects as restrictive for insert to authenticated
with check (not exists (
  select 1 from public.education_levels l
  where l.id=education_subjects.education_level_id and l.code='university'
));
create policy staging_pause_university_course_update
on public.education_subjects as restrictive for update to authenticated
using (not exists (
  select 1 from public.education_levels l
  where l.id=education_subjects.education_level_id and l.code='university'
))
with check (not exists (
  select 1 from public.education_levels l
  where l.id=education_subjects.education_level_id and l.code='university'
));

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $university_write_freeze$
declare
  v_thpt uuid;
  v_university uuid;
  v_group uuid;
  v_thpt_course uuid;
  v_rejected boolean;
  v_updated integer;
begin
  select id into v_thpt from public.education_levels where code='thpt';
  select id into v_university from public.education_levels where code='university';
  select id into v_group from public.education_subject_groups where education_level_id=v_university and code='unclassified';
  v_rejected := false;
  begin
    insert into public.education_subjects(education_level_id,group_id,display_name)
    values(v_university,v_group,'Freeze blocks University insert');
  exception when insufficient_privilege then
    v_rejected := true;
  end;
  if not v_rejected then raise exception 'University course write freeze did not block INSERT.'; end if;

  update public.education_subjects set display_name=display_name where id='69000000-0000-4000-8000-000000000010';
  get diagnostics v_updated = row_count;
  if v_updated <> 0 then raise exception 'University course write freeze did not block UPDATE.'; end if;

  insert into public.education_subjects(education_level_id,display_name,local_code)
  values(v_thpt,'Freeze allows THPT direct course','FREEZE-THPT') returning id into v_thpt_course;
  update public.education_subjects set display_name='Freeze allows THPT edit' where id=v_thpt_course;
  if not exists (select 1 from public.education_subjects where id=v_thpt_course and group_id is null and display_name='Freeze allows THPT edit') then
    raise exception 'University course write freeze unexpectedly blocked direct THPT course writes.';
  end if;
end;
$university_write_freeze$;
reset role;
drop policy staging_pause_university_course_insert on public.education_subjects;
drop policy staging_pause_university_course_update on public.education_subjects;

set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $anon_group_rls$
declare
  v_visible_groups integer := 0;
  v_select_allowed boolean := true;
begin
  begin
    select count(*) into v_visible_groups from public.education_subject_groups;
  exception when insufficient_privilege then
    v_select_allowed := false;
  end;
  if v_select_allowed and v_visible_groups <> 0 then
    raise exception 'Unauthenticated role unexpectedly read % education groups.',v_visible_groups;
  end if;
end;
$anon_group_rls$;
reset role;

rollback;
