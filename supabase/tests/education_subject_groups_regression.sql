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
end;
$assert$;

rollback;
