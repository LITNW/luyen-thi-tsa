-- Enforce education placement at the database boundary for every publication path.
-- The legacy editor wrapper is not the only possible caller of admin_publish_exam_version.

begin;

create or replace function public.education_exam_version_publish_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_placement_active boolean;
begin
  if new.status <> 'published' then
    return new;
  end if;

  select exists (
    select 1
    from public.exams e
    join public.education_subjects es
      on es.id = e.education_subject_id
    join public.education_levels l
      on l.id = es.education_level_id
    left join public.education_nodes n
      on n.id = es.education_node_id
     and n.education_level_id = es.education_level_id
    where e.id = new.exam_id
      and es.is_active
      and l.is_active
      and (es.education_node_id is null or n.is_active)
  )
  into v_placement_active;

  if not coalesce(v_placement_active, false) then
    raise exception using
      errcode = '23514',
      message = 'An exam must have an active education subject placement before any version can be published.';
  end if;

  return new;
end;
$function$;

revoke all on function public.education_exam_version_publish_guard() from public, anon, authenticated;

create trigger exam_versions_education_publish_guard
before insert or update of status
on public.exam_versions
for each row
execute function public.education_exam_version_publish_guard();

commit;
