-- Strengthen education hierarchy invariants after initial Staging smoke testing.
-- Stable identity fields cannot be rewritten once downstream content depends on them.

begin;

create or replace function public.education_nodes_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_level_active boolean;
  v_parent_type text;
  v_parent_active boolean;
  v_cycle boolean;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.education_level_id::text,0)
  );

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
      message = 'An active education node must belong to an active education level.';
  end if;

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

    if new.node_type in ('grade','institution') then
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

create or replace function public.education_level_code_immutable()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if new.code is distinct from old.code then
    raise exception using
      errcode = '23514',
      message = 'Education level code is immutable.';
  end if;
  return new;
end;
$function$;

create trigger education_levels_code_immutable
before update of code on public.education_levels
for each row execute function public.education_level_code_immutable();

create or replace function public.education_nodes_identity_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if (
    new.education_level_id is distinct from old.education_level_id
    or new.parent_id is distinct from old.parent_id
    or new.node_type is distinct from old.node_type
    or new.code is distinct from old.code
  ) and (
    exists (
      select 1 from public.education_nodes child
      where child.parent_id=old.id
    )
    or exists (
      select 1 from public.education_subjects offering
      where offering.education_node_id=old.id
    )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Education node identity cannot be changed while child nodes or subject offerings depend on it.';
  end if;
  return new;
end;
$function$;

create trigger education_nodes_identity_guard_before_update
before update of education_level_id,parent_id,node_type,code
on public.education_nodes
for each row execute function public.education_nodes_identity_guard();

create or replace function public.education_subjects_identity_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if (
    new.education_level_id is distinct from old.education_level_id
    or new.education_node_id is distinct from old.education_node_id
    or new.subject_id is distinct from old.subject_id
  ) and exists (
    select 1 from public.exams e
    where e.education_subject_id=old.id
  ) then
    raise exception using
      errcode = '23514',
      message = 'Education subject offering identity cannot be changed while exams depend on it.';
  end if;
  return new;
end;
$function$;

create trigger education_subjects_identity_guard_before_update
before update of education_level_id,education_node_id,subject_id
on public.education_subjects
for each row execute function public.education_subjects_identity_guard();

commit;
