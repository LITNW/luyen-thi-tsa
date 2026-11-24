-- Protect Admin-managed course categories and courses from unsafe direct deletes.
-- The existing exams_education_subject_fk remains ON DELETE RESTRICT, so races
-- between the Admin pre-check and a new exam reference cannot remove course data.

begin;

create or replace function public.education_course_category_delete_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if not public.is_admin() then
    raise exception using errcode='42501', message='Only an Admin may manage education course categories.';
  end if;

  if tg_op = 'DELETE' then
    if old.code = 'unclassified' then
      raise exception using errcode='23514', message='The default unclassified course category cannot be deleted.';
    end if;

    if exists (
      select 1 from public.education_subjects es where es.category_id=old.id
    ) then
      raise exception using errcode='23503', message='Move all courses out of this category before deleting it.';
    end if;
    return old;
  end if;

  if old.code = 'unclassified' and (
    new.code is distinct from old.code
    or new.education_level_id is distinct from old.education_level_id
    or not new.is_active
  ) then
    raise exception using errcode='23514', message='The default unclassified category must keep its code, education level, and active status.';
  end if;

  return new;
end;
$function$;

create trigger education_course_categories_delete_guard
before delete or update of code,education_level_id,is_active
on public.education_course_categories
for each row execute function public.education_course_category_delete_guard();

create or replace function public.education_subject_delete_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if not public.is_admin() then
    raise exception using errcode='42501', message='Only an Admin may manage education courses.';
  end if;

  if exists (
    select 1 from public.exams e where e.education_subject_id=old.id
  ) then
    raise exception using errcode='23503', message='This course is referenced by an exam and cannot be deleted. Hide it instead.';
  end if;

  return old;
end;
$function$;

create trigger education_subjects_delete_guard_before_delete
before delete on public.education_subjects
for each row execute function public.education_subject_delete_guard();

-- The composite category FK and exams_education_subject_fk both use RESTRICT.
-- Keep those database constraints as the final concurrency-safe dependency guard.
revoke all on function public.education_course_category_delete_guard() from public, anon, authenticated;
revoke all on function public.education_subject_delete_guard() from public, anon, authenticated;

commit;
