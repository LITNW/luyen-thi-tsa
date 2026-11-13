-- Education hierarchy foundation (additive; preserves all existing exam/history data).
-- Student navigation will consume this model in a later application PR.
-- Existing exams remain unplaced (education_subject_id NULL) until an Admin classifies them.

begin;

create table public.education_levels (
  id uuid primary key default gen_random_uuid(),
  code text not null unique
    check (code ~ '^[a-z][a-z0-9_]{1,63}$'),
  name text not null check (length(btrim(name)) between 1 and 120),
  description text not null default '',
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.education_nodes (
  id uuid primary key default gen_random_uuid(),
  education_level_id uuid not null
    references public.education_levels(id) on delete restrict,
  parent_id uuid null,
  node_type text not null
    check (node_type in ('grade','institution','program','major','custom')),
  code text not null
    check (code ~ '^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$'),
  name text not null check (length(btrim(name)) between 1 and 160),
  description text not null default '',
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint education_nodes_level_id_id_unique unique (education_level_id,id),
  constraint education_nodes_parent_not_self check (parent_id is null or parent_id <> id),
  constraint education_nodes_parent_same_level_fk
    foreign key (education_level_id,parent_id)
    references public.education_nodes(education_level_id,id)
    on delete restrict
);

create unique index education_nodes_root_code_uidx
  on public.education_nodes(education_level_id,code)
  where parent_id is null;
create unique index education_nodes_child_code_uidx
  on public.education_nodes(education_level_id,parent_id,code)
  where parent_id is not null;
create index education_nodes_level_parent_order_idx
  on public.education_nodes(education_level_id,parent_id,display_order,id);
create index education_nodes_active_level_idx
  on public.education_nodes(education_level_id,is_active,display_order);

create table public.education_subjects (
  id uuid primary key default gen_random_uuid(),
  education_level_id uuid not null
    references public.education_levels(id) on delete restrict,
  education_node_id uuid null,
  subject_id uuid not null
    references public.subjects(id) on delete restrict,
  local_code text null
    check (local_code is null or length(btrim(local_code)) between 1 and 64),
  display_name text not null
    check (length(btrim(display_name)) between 1 and 160),
  description text not null default '',
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint education_subjects_node_same_level_fk
    foreign key (education_level_id,education_node_id)
    references public.education_nodes(education_level_id,id)
    on delete restrict
);

create unique index education_subjects_context_subject_uidx
  on public.education_subjects(
    education_level_id,
    coalesce(education_node_id,'00000000-0000-0000-0000-000000000000'::uuid),
    subject_id
  );
create unique index education_subjects_context_local_code_uidx
  on public.education_subjects(
    education_level_id,
    coalesce(education_node_id,'00000000-0000-0000-0000-000000000000'::uuid),
    local_code
  )
  where local_code is not null;
create index education_subjects_level_node_active_idx
  on public.education_subjects(education_level_id,education_node_id,is_active,display_order);
create index education_subjects_subject_idx
  on public.education_subjects(subject_id);

-- Stable exam identity points to one contextual subject offering.
-- Nullable during the expand/backfill/switch migration period.
alter table public.exams
  add column education_subject_id uuid null;
alter table public.exams
  add constraint exams_education_subject_fk
  foreign key (education_subject_id)
  references public.education_subjects(id)
  on delete restrict;
create index exams_education_subject_id_idx
  on public.exams(education_subject_id);

create or replace function public.education_hierarchy_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$function$;

create trigger education_levels_set_updated_at
before update on public.education_levels
for each row execute function public.education_hierarchy_set_updated_at();

create trigger education_nodes_set_updated_at
before update on public.education_nodes
for each row execute function public.education_hierarchy_set_updated_at();

create trigger education_subjects_set_updated_at
before update on public.education_subjects
for each row execute function public.education_hierarchy_set_updated_at();

create or replace function public.education_levels_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if old.is_active and not new.is_active and (
    exists (
      select 1 from public.education_nodes n
      where n.education_level_id=old.id and n.is_active
    )
    or exists (
      select 1 from public.education_subjects s
      where s.education_level_id=old.id and s.is_active
    )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Deactivate active education nodes and subject offerings before deactivating the level.';
  end if;
  return new;
end;
$function$;

create trigger education_levels_guard_before_update
before update of is_active on public.education_levels
for each row execute function public.education_levels_guard();

create or replace function public.education_nodes_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_parent_type text;
  v_parent_active boolean;
  v_cycle boolean;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.education_level_id::text,0)
  );

  if new.parent_id is not null then
    select n.node_type,n.is_active
    into v_parent_type,v_parent_active
    from public.education_nodes n
    where n.id=new.parent_id
      and n.education_level_id=new.education_level_id;

    if not found then
      raise exception using
        errcode = '23503',
        message = 'The parent education node does not exist in this education level.';
    end if;

    if new.is_active and not v_parent_active then
      raise exception using
        errcode = '23514',
        message = 'An active education node must have an active parent.';
    end if;

    if new.node_type='grade' or new.node_type='institution' then
      raise exception using
        errcode = '23514',
        message = 'Grade and institution nodes must be top-level nodes.';
    end if;

    if new.node_type='program' and v_parent_type not in ('institution','custom') then
      raise exception using
        errcode = '23514',
        message = 'A program node must be nested under an institution or custom context.';
    end if;

    if new.node_type='major' and v_parent_type not in ('institution','program','custom') then
      raise exception using
        errcode = '23514',
        message = 'A major node must be nested under an institution, program or custom context.';
    end if;

    with recursive ancestors(id,parent_id) as (
      select n.id,n.parent_id
      from public.education_nodes n
      where n.id=new.parent_id
        and n.education_level_id=new.education_level_id
      union all
      select parent.id,parent.parent_id
      from public.education_nodes parent
      join ancestors child on parent.id=child.parent_id
      where parent.education_level_id=new.education_level_id
    )
    select exists(select 1 from ancestors where id=new.id)
    into v_cycle;

    if v_cycle then
      raise exception using
        errcode = '23514',
        message = 'Education node hierarchy cannot contain a cycle.';
    end if;
  end if;

  if not new.is_active and (
    exists (
      select 1 from public.education_nodes child
      where child.parent_id=new.id and child.is_active
    )
    or exists (
      select 1 from public.education_subjects offering
      where offering.education_node_id=new.id and offering.is_active
    )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Deactivate active child nodes and subject offerings before deactivating this node.';
  end if;

  return new;
end;
$function$;

create trigger education_nodes_guard_before_write
before insert or update of education_level_id,parent_id,node_type,is_active
on public.education_nodes
for each row execute function public.education_nodes_guard();

create or replace function public.education_subjects_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_level_active boolean;
  v_node_active boolean;
begin
  select l.is_active into v_level_active
  from public.education_levels l
  where l.id=new.education_level_id;

  if not found then
    raise exception using
      errcode = '23503',
      message = 'Education level does not exist.';
  end if;

  if new.is_active and not v_level_active then
    raise exception using
      errcode = '23514',
      message = 'An active subject offering must belong to an active education level.';
  end if;

  if new.education_node_id is not null then
    select n.is_active into v_node_active
    from public.education_nodes n
    where n.id=new.education_node_id
      and n.education_level_id=new.education_level_id;

    if not found then
      raise exception using
        errcode = '23503',
        message = 'Education node does not exist in the selected education level.';
    end if;

    if new.is_active and not v_node_active then
      raise exception using
        errcode = '23514',
        message = 'An active subject offering must belong to an active education node.';
    end if;
  end if;

  return new;
end;
$function$;

create trigger education_subjects_guard_before_write
before insert or update of education_level_id,education_node_id,subject_id,is_active
on public.education_subjects
for each row execute function public.education_subjects_guard();

alter table public.education_levels enable row level security;
alter table public.education_nodes enable row level security;
alter table public.education_subjects enable row level security;

grant select,insert,update,delete on public.education_levels to authenticated;
grant select,insert,update,delete on public.education_nodes to authenticated;
grant select,insert,update,delete on public.education_subjects to authenticated;

create policy education_levels_read_active_or_admin
on public.education_levels
for select to authenticated
using (is_active or (select public.is_admin()));

create policy education_levels_admin_write
on public.education_levels
for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

create policy education_nodes_read_active_or_admin
on public.education_nodes
for select to authenticated
using (
  (is_active and exists (
    select 1 from public.education_levels l
    where l.id=education_level_id and l.is_active
  ))
  or (select public.is_admin())
);

create policy education_nodes_admin_write
on public.education_nodes
for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

create policy education_subjects_read_active_or_admin
on public.education_subjects
for select to authenticated
using (
  (
    is_active
    and exists (
      select 1 from public.education_levels l
      where l.id=education_level_id and l.is_active
    )
    and (
      education_node_id is null
      or exists (
        select 1 from public.education_nodes n
        where n.id=education_node_id
          and n.education_level_id=education_level_id
          and n.is_active
      )
    )
  )
  or (select public.is_admin())
);

create policy education_subjects_admin_write
on public.education_subjects
for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

insert into public.education_levels(code,name,description,display_order)
values
  ('thpt','THPT','Trung học phổ thông',1),
  ('university','Đại học','Giáo dục đại học',2)
on conflict (code) do update
set name=excluded.name,
    description=excluded.description,
    display_order=excluded.display_order;

commit;
