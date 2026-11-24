-- Replace active university classification with editable, level-scoped course categories.
-- Legacy hierarchy/catalogue fields remain temporarily for SQL compatibility and are
-- no longer part of the active education workflow.
-- Course IDs and exams.education_subject_id are left untouched.

begin;

create table public.education_course_categories (
  id uuid primary key default gen_random_uuid(),
  education_level_id uuid not null references public.education_levels(id) on delete restrict,
  code text not null check (code ~ '^[a-z][a-z0-9_]{1,63}$'),
  name text not null check (length(btrim(name)) between 1 and 160),
  description text not null default '',
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint education_course_categories_level_id_id_unique unique (education_level_id,id),
  constraint education_course_categories_level_code_unique unique (education_level_id,code)
);

create index education_course_categories_active_order_idx
  on public.education_course_categories(education_level_id,is_active,display_order,id);

alter table public.education_subjects add column category_id uuid null;
-- New courses are self-contained records; existing legacy subject links stay intact.
alter table public.education_subjects alter column subject_id drop not null;
alter table public.education_subjects
  add constraint education_subjects_category_same_level_fk
  foreign key (education_level_id,category_id)
  references public.education_course_categories(education_level_id,id)
  on delete restrict;

create index education_subjects_level_category_active_idx
  on public.education_subjects(education_level_id,category_id,is_active,display_order,id);

-- Only the neutral category is seeded; Admin manages all other categories as ordinary records.
insert into public.education_course_categories(education_level_id,code,name,display_order)
select l.id,'unclassified','Chưa phân loại',0
from public.education_levels l
where l.code='university'
on conflict (education_level_id,code) do update
set name=excluded.name,display_order=excluded.display_order;

update public.education_subjects es
set category_id=g.id
from public.education_levels l
join public.education_course_categories g on g.education_level_id=l.id and g.code='unclassified'
where es.education_level_id=l.id and l.code='university' and es.category_id is null;

create or replace function public.education_subject_category_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_level_code text;
  v_category_active boolean;
begin
  select l.code into v_level_code
  from public.education_levels l where l.id=new.education_level_id;
  if not found then
    raise exception using errcode='23503', message='Education level does not exist.';
  end if;

  if v_level_code='thpt' and new.category_id is not null then
    raise exception using errcode='23514', message='THPT courses must not be assigned to a course category.';
  end if;

  if v_level_code='university' and new.category_id is null then
    raise exception using errcode='23514', message='University courses must belong to a course category.';
  end if;

  if new.category_id is not null then
    select g.is_active into v_category_active
    from public.education_course_categories g
    where g.id=new.category_id and g.education_level_id=new.education_level_id;
    if not found then
      raise exception using errcode='23503', message='Course category does not belong to the selected education level.';
    end if;
    if new.is_active and not v_category_active then
      raise exception using errcode='23514', message='An active course must belong to an active course category.';
    end if;
  end if;
  return new;
end;
$function$;

create trigger education_subjects_category_guard
before insert or update of education_level_id,category_id,is_active
on public.education_subjects
for each row execute function public.education_subject_category_guard();

create or replace function public.education_course_categories_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.is_active and not new.is_active and exists (
    select 1 from public.education_subjects es where es.category_id=old.id and es.is_active
  ) then
    raise exception using errcode='23514', message='Deactivate or move active courses before deactivating this category.';
  end if;
  return new;
end;
$function$;

create trigger education_course_categories_guard_before_update
before update of is_active on public.education_course_categories
for each row execute function public.education_course_categories_guard();

create trigger education_course_categories_set_updated_at
before update on public.education_course_categories
for each row execute function public.education_hierarchy_set_updated_at();

alter table public.education_course_categories enable row level security;
grant select,insert,update,delete on public.education_course_categories to authenticated;

create policy education_course_categories_read_active_or_admin
on public.education_course_categories for select to authenticated
using (
  (is_active and exists (
    select 1 from public.education_levels l where l.id=education_level_id and l.is_active
  ) and exists (
    select 1 from public.profiles p where p.id=(select auth.uid()) and p.status='active'
  )) or (select public.is_admin())
);

create policy education_course_categories_admin_write
on public.education_course_categories for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

commit;
