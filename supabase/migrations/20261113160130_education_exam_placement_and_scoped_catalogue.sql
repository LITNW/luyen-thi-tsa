-- Education-subject placement and scoped Student exam catalogue.
-- Existing exams remain unplaced until explicitly classified by an Admin.

begin;

create or replace function public.education_exam_placement_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_offering_active boolean;
  v_level_active boolean;
  v_node_active boolean;
begin
  if new.education_subject_id is null then
    return new;
  end if;

  select es.is_active,l.is_active,
         case when es.education_node_id is null then true else n.is_active end
  into v_offering_active,v_level_active,v_node_active
  from public.education_subjects es
  join public.education_levels l on l.id=es.education_level_id
  left join public.education_nodes n
    on n.id=es.education_node_id
   and n.education_level_id=es.education_level_id
  where es.id=new.education_subject_id;

  if not found then
    raise exception using
      errcode = '23503',
      message = 'The selected education subject offering does not exist.';
  end if;

  if not v_offering_active or not v_level_active or not v_node_active then
    raise exception using
      errcode = '23514',
      message = 'An exam must be assigned to an active education subject offering and active education path.';
  end if;

  if tg_op='UPDATE'
     and old.education_subject_id is not null
     and new.education_subject_id is distinct from old.education_subject_id
     and exists (
       select 1 from public.attempts a where a.exam_id=old.id
     ) then
    raise exception using
      errcode = '23514',
      message = 'An exam placement cannot be changed after it has already been classified and has student attempts.';
  end if;

  return new;
end;
$function$;

create trigger exams_education_placement_guard
before insert or update of education_subject_id
on public.exams
for each row execute function public.education_exam_placement_guard();

create or replace function public.admin_set_exam_education_subject(
  p_exam_id uuid,
  p_education_subject_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only an active Admin may assign an exam to an education subject.';
  end if;

  update public.exams
  set education_subject_id=p_education_subject_id
  where id=p_exam_id;

  if not found then
    raise exception 'Exam was not found.';
  end if;

  return true;
end;
$function$;

revoke all on function public.admin_set_exam_education_subject(uuid,uuid) from public,anon;
grant execute on function public.admin_set_exam_education_subject(uuid,uuid) to authenticated;

create or replace function public.list_published_exams_for_education_subject(
  p_education_subject_id uuid
)
returns table (
  id uuid,
  exam_id uuid,
  version_no integer,
  title text,
  description text,
  duration_minutes integer,
  published_at timestamptz,
  question_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles p
    where p.id=auth.uid() and p.status='active'
  ) then
    raise exception 'An active authenticated account is required.';
  end if;

  if not exists (
    select 1
    from public.education_subjects es
    join public.education_levels l on l.id=es.education_level_id
    left join public.education_nodes n
      on n.id=es.education_node_id
     and n.education_level_id=es.education_level_id
    where es.id=p_education_subject_id
      and es.is_active
      and l.is_active
      and (es.education_node_id is null or n.is_active)
  ) then
    raise exception 'The education subject is unavailable.';
  end if;

  return query
  select
    ev.id,
    ev.exam_id,
    ev.version_no,
    ev.title,
    ev.description,
    ev.duration_minutes,
    ev.published_at,
    (
      select count(*) from public.exam_version_questions evq
      where evq.exam_version_id=ev.id
    ) as question_count
  from public.exam_versions ev
  join public.exams e on e.id=ev.exam_id
  where e.education_subject_id=p_education_subject_id
    and ev.status='published'
    and ev.archived_at is null
  order by ev.published_at desc nulls last,ev.created_at desc;
end;
$function$;

revoke all on function public.list_published_exams_for_education_subject(uuid) from public,anon;
grant execute on function public.list_published_exams_for_education_subject(uuid) to authenticated;

commit;
