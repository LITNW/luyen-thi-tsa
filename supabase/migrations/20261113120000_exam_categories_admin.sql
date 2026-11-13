-- M2: exam categories and backward-compatible Admin RPCs.
-- Categories classify the stable exam identity (public.exams), not individual versions.
-- Existing exams remain uncategorized (category_id NULL); no attempt/history tables are changed.

begin;

create table public.exam_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 120),
  slug text not null unique
    check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  description text not null default '',
  parent_id uuid null,
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exam_categories_parent_not_self check (parent_id is null or parent_id <> id),
  constraint exam_categories_parent_fk
    foreign key (parent_id) references public.exam_categories(id) on delete restrict
);

create index exam_categories_parent_order_idx
  on public.exam_categories(parent_id,display_order,name);
create index exam_categories_active_order_idx
  on public.exam_categories(is_active,display_order,name);

alter table public.exams
  add column category_id uuid null;

alter table public.exams
  add constraint exams_category_id_fkey
  foreign key (category_id)
  references public.exam_categories(id)
  on delete set null;

create index exams_category_id_idx on public.exams(category_id);

create or replace function public.m2_set_exam_category_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$function$;

create trigger exam_categories_set_updated_at
before update on public.exam_categories
for each row execute function public.m2_set_exam_category_updated_at();

create or replace function public.m2_validate_exam_category_hierarchy()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_cycle boolean;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('tsa-exam-category-hierarchy',0)
  );

  if new.parent_id is not null then
    if not exists (
      select 1 from public.exam_categories parent
      where parent.id = new.parent_id
        and parent.is_active
    ) and new.is_active then
      raise exception using
        errcode = '23514',
        message = 'An active exam category must have an active parent.';
    end if;

    with recursive ancestors(id,parent_id) as (
      select c.id,c.parent_id
      from public.exam_categories c
      where c.id = new.parent_id
      union all
      select parent.id,parent.parent_id
      from public.exam_categories parent
      join ancestors child on parent.id = child.parent_id
    )
    select exists(select 1 from ancestors where id = new.id)
    into v_cycle;

    if v_cycle then
      raise exception using
        errcode = '23514',
        message = 'Exam category hierarchy cannot contain a cycle.';
    end if;
  end if;

  if not new.is_active and exists (
    select 1 from public.exam_categories child
    where child.parent_id = new.id and child.is_active
  ) then
    raise exception using
      errcode = '23514',
      message = 'Archive active child categories before archiving their parent.';
  end if;

  return new;
end;
$function$;

create trigger exam_categories_hierarchy_guard
before insert or update of parent_id,is_active on public.exam_categories
for each row execute function public.m2_validate_exam_category_hierarchy();

alter table public.exam_categories enable row level security;

grant select,insert,update,delete on public.exam_categories to authenticated;

create policy exam_categories_read_active_or_admin
on public.exam_categories
for select to authenticated
using (is_active or (select public.is_admin()));

create policy exam_categories_admin_insert
on public.exam_categories
for insert to authenticated
with check ((select public.is_admin()));

create policy exam_categories_admin_update
on public.exam_categories
for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

create policy exam_categories_admin_delete
on public.exam_categories
for delete to authenticated
using ((select public.is_admin()));

create or replace function public.list_active_exam_categories()
returns table (
  id uuid,
  name text,
  slug text,
  description text,
  parent_id uuid,
  display_order integer
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.status = 'active'
  ) then
    raise exception 'An active authenticated account is required.';
  end if;

  return query
  select c.id,c.name,c.slug,c.description,c.parent_id,c.display_order
  from public.exam_categories c
  where c.is_active
  order by c.display_order,c.name;
end;
$function$;

create or replace function public.admin_list_exam_categories()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only an active Admin may list exam categories.';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.display_order,x.name),'[]'::jsonb)
  into v_result
  from (
    select c.id,c.name,c.slug,c.description,c.parent_id,c.is_active,
      c.display_order,c.created_at,c.updated_at,
      (select count(*) from public.exams e where e.category_id=c.id) as exam_count
    from public.exam_categories c
  ) x;

  return v_result;
end;
$function$;

create or replace function public.admin_save_exam_category(
  p_name text,
  p_slug text,
  p_category_id uuid default null,
  p_description text default '',
  p_parent_id uuid default null,
  p_is_active boolean default true,
  p_display_order integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_category public.exam_categories%rowtype;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only an active Admin may create or update exam categories.';
  end if;

  if nullif(btrim(p_name),'') is null or char_length(btrim(p_name)) > 120 then
    raise exception 'Category name must contain 1 to 120 characters.';
  end if;
  if p_slug is null or p_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
     or char_length(p_slug) > 120 then
    raise exception 'Category slug must use lowercase letters, numbers, and single hyphens.';
  end if;
  if p_category_id is not null and p_parent_id = p_category_id then
    raise exception 'A category cannot be its own parent.';
  end if;
  if p_parent_id is not null and not exists (
    select 1 from public.exam_categories c
    where c.id=p_parent_id and c.is_active
  ) and coalesce(p_is_active,true) then
    raise exception 'An active category must have an active parent.';
  end if;

  if p_category_id is null then
    insert into public.exam_categories(
      name,slug,description,parent_id,is_active,display_order,created_by
    ) values (
      btrim(p_name),p_slug,coalesce(p_description,''),p_parent_id,
      coalesce(p_is_active,true),coalesce(p_display_order,0),auth.uid()
    )
    returning * into v_category;
  else
    update public.exam_categories
    set name=btrim(p_name),
        slug=p_slug,
        description=coalesce(p_description,''),
        parent_id=p_parent_id,
        is_active=coalesce(p_is_active,true),
        display_order=coalesce(p_display_order,0)
    where id=p_category_id
    returning * into v_category;

    if not found then
      raise exception 'Exam category was not found.';
    end if;
  end if;

  return jsonb_build_object(
    'id',v_category.id,
    'name',v_category.name,
    'slug',v_category.slug,
    'description',v_category.description,
    'parent_id',v_category.parent_id,
    'is_active',v_category.is_active,
    'display_order',v_category.display_order,
    'created_at',v_category.created_at,
    'updated_at',v_category.updated_at
  );
end;
$function$;

create or replace function public.admin_set_exam_category(
  p_exam_id uuid,
  p_category_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_locked_category_id uuid;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only an active Admin may assign an exam category.';
  end if;

  if p_category_id is not null then
    select c.id into v_locked_category_id
    from public.exam_categories c
    where c.id=p_category_id and c.is_active
    for share;
    if not found then
      raise exception 'The selected exam category does not exist or is inactive.';
    end if;
  end if;

  update public.exams
  set category_id=p_category_id
  where id=p_exam_id;

  if not found then
    raise exception 'Exam was not found.';
  end if;

  return true;
end;
$function$;

-- New wrapper preserves the existing six-argument legacy RPC contract unchanged.
-- The save and category assignment run in the same transaction.
create or replace function public.admin_save_exam_content_with_category(
  p_exam_version_id uuid,
  p_title text,
  p_description text,
  p_duration_minutes integer,
  p_questions jsonb,
  p_category_id uuid,
  p_publish boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_result jsonb;
  v_exam_id uuid;
  v_locked_category_id uuid;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only an active Admin may save an exam with a category.';
  end if;

  if p_category_id is not null then
    select c.id into v_locked_category_id
    from public.exam_categories c
    where c.id=p_category_id and c.is_active
    for share;
    if not found then
      raise exception 'The selected exam category does not exist or is inactive.';
    end if;
  end if;

  v_result := public.admin_save_exam_content(
    p_exam_version_id,p_title,p_description,p_duration_minutes,p_questions,p_publish
  );

  v_exam_id := nullif(v_result->>'exam_id','')::uuid;
  if v_exam_id is null then
    raise exception 'Legacy exam save did not return an exam identity.';
  end if;

  update public.exams
  set category_id=p_category_id
  where id=v_exam_id;

  if not found then
    raise exception 'Exam identity was not found after saving the exam.';
  end if;

  return v_result || jsonb_build_object('category_id',p_category_id);
end;
$function$;

create or replace function public.admin_list_exam_versions_with_categories()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only an active Admin may list exam versions.';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'exam_id',ev.exam_id,
      'exam_version_id',ev.id,
      'version_no',ev.version_no,
      'title',ev.title,
      'description',ev.description,
      'duration_minutes',ev.duration_minutes,
      'status',ev.status,
      'created_at',ev.created_at,
      'published_at',ev.published_at,
      'question_count',(
        select count(*) from public.exam_version_questions evq
        where evq.exam_version_id=ev.id
      ),
      'attempt_count',(
        select count(*) from public.attempts a
        where a.exam_version_id=ev.id
      ),
      'category_id',e.category_id,
      'category_name',c.name,
      'category_slug',c.slug
    ) order by ev.created_at desc
  ),'[]'::jsonb)
  into v_result
  from public.exam_versions ev
  join public.exams e on e.id=ev.exam_id
  left join public.exam_categories c on c.id=e.category_id;

  return v_result;
end;
$function$;

revoke all on function public.list_active_exam_categories() from public,anon;
revoke all on function public.admin_list_exam_categories() from public,anon;
revoke all on function public.admin_save_exam_category(text,text,uuid,text,uuid,boolean,integer) from public,anon;
revoke all on function public.admin_set_exam_category(uuid,uuid) from public,anon;
revoke all on function public.admin_save_exam_content_with_category(uuid,text,text,integer,jsonb,uuid,boolean) from public,anon;
revoke all on function public.admin_list_exam_versions_with_categories() from public,anon;

grant execute on function public.list_active_exam_categories() to authenticated;
grant execute on function public.admin_list_exam_categories() to authenticated;
grant execute on function public.admin_save_exam_category(text,text,uuid,text,uuid,boolean,integer) to authenticated;
grant execute on function public.admin_set_exam_category(uuid,uuid) to authenticated;
grant execute on function public.admin_save_exam_content_with_category(uuid,text,text,integer,jsonb,uuid,boolean) to authenticated;
grant execute on function public.admin_list_exam_versions_with_categories() to authenticated;

commit;
