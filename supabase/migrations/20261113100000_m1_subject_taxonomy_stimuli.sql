-- M1: additive multi-subject foundation (subjects, taxonomy, reusable stimuli).
-- This migration deliberately does not modify legacy exam, question, or attempt tables.
-- No existing question versions are backfilled or assigned to a subject/taxonomy.

begin;

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  code text not null unique
    check (code ~ '^[a-z][a-z0-9_]{1,63}$'),
  name text not null check (length(btrim(name)) between 1 and 120),
  description text,
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.taxonomy_nodes (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete restrict,
  parent_id uuid null,
  node_type text not null
    check (node_type in ('domain','topic','skill','competency')),
  code text not null check (code ~ '^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$'),
  name text not null check (length(btrim(name)) between 1 and 160),
  description text,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint taxonomy_nodes_subject_id_id_unique unique (subject_id,id),
  constraint taxonomy_nodes_parent_not_self check (parent_id is null or parent_id <> id),
  constraint taxonomy_nodes_parent_same_subject_fk
    foreign key (subject_id,parent_id)
    references public.taxonomy_nodes(subject_id,id)
    on delete restrict
);

create unique index taxonomy_nodes_root_code_uidx
  on public.taxonomy_nodes(subject_id,code)
  where parent_id is null;
create unique index taxonomy_nodes_child_code_uidx
  on public.taxonomy_nodes(subject_id,parent_id,code)
  where parent_id is not null;
create index taxonomy_nodes_subject_parent_position_idx
  on public.taxonomy_nodes(subject_id,parent_id,display_order,id);
create index taxonomy_nodes_subject_type_idx
  on public.taxonomy_nodes(subject_id,node_type,is_active);

create table public.question_version_taxonomy (
  question_version_id uuid not null
    references public.question_versions(id) on delete restrict,
  taxonomy_node_id uuid not null
    references public.taxonomy_nodes(id) on delete restrict,
  relation_type text not null
    check (relation_type in ('primary_topic','secondary_topic','skill','competency')),
  created_at timestamptz not null default now(),
  primary key (question_version_id,taxonomy_node_id)
);
create index question_version_taxonomy_node_question_idx
  on public.question_version_taxonomy(taxonomy_node_id,question_version_id);
create unique index question_version_taxonomy_one_primary_topic_uidx
  on public.question_version_taxonomy(question_version_id)
  where relation_type = 'primary_topic';

create table public.stimuli (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'draft'
    check (status in ('draft','active','archived')),
  created_by uuid null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index stimuli_status_created_at_idx
  on public.stimuli(status,created_at desc);

create table public.stimulus_versions (
  id uuid primary key default gen_random_uuid(),
  stimulus_id uuid not null
    references public.stimuli(id) on delete restrict,
  version_no integer not null check (version_no > 0),
  stimulus_type text not null
    check (stimulus_type in ('text','table','chart','image','dataset','experiment','mixed')),
  content jsonb not null
    check (jsonb_typeof(content) = 'object'),
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  created_by uuid null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint stimulus_versions_stimulus_version_unique unique(stimulus_id,version_no)
);
create index stimulus_versions_stimulus_created_idx
  on public.stimulus_versions(stimulus_id,created_at desc);

-- Shared updated_at handler for mutable identity/metadata tables only.
create or replace function public.m1_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$function$;

create trigger subjects_set_updated_at
before update on public.subjects
for each row execute function public.m1_set_updated_at();
create trigger taxonomy_nodes_set_updated_at
before update on public.taxonomy_nodes
for each row execute function public.m1_set_updated_at();
create trigger stimuli_set_updated_at
before update on public.stimuli
for each row execute function public.m1_set_updated_at();

-- Serialize hierarchy changes per subject and reject cycles, including concurrent re-parenting.
create or replace function public.m1_validate_taxonomy_parent()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_cycle boolean;
begin
  if new.parent_id is null then
    return new;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.subject_id::text,0)
  );

  with recursive ancestors(id,parent_id) as (
    select n.id,n.parent_id
    from public.taxonomy_nodes n
    where n.id = new.parent_id
      and n.subject_id = new.subject_id
    union all
    select parent.id,parent.parent_id
    from public.taxonomy_nodes parent
    join ancestors child on parent.id = child.parent_id
    where parent.subject_id = new.subject_id
  )
  select exists(select 1 from ancestors where id = new.id)
  into v_cycle;

  if v_cycle then
    raise exception using
      errcode = '23514',
      message = 'Taxonomy hierarchy cannot contain a cycle.';
  end if;

  return new;
end;
$function$;

create trigger taxonomy_nodes_prevent_cycle
before insert or update of parent_id,subject_id on public.taxonomy_nodes
for each row execute function public.m1_validate_taxonomy_parent();

-- A referenced taxonomy node may be renamed only for display correction.
-- Its subject, stable code, node type, and parent meaning cannot be rewritten.
create or replace function public.m1_protect_referenced_taxonomy_identity()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if exists (
    select 1 from public.question_version_taxonomy qvt
    where qvt.taxonomy_node_id = old.id
  ) and (
    new.subject_id is distinct from old.subject_id
    or new.parent_id is distinct from old.parent_id
    or new.code is distinct from old.code
    or new.node_type is distinct from old.node_type
  ) then
    raise exception using
      errcode = '23514',
      message = 'Referenced taxonomy identity is immutable; create a replacement node instead.';
  end if;
  return new;
end;
$function$;

create trigger taxonomy_nodes_protect_referenced_identity
before update on public.taxonomy_nodes
for each row execute function public.m1_protect_referenced_taxonomy_identity();

-- A question version already used by a published exam must retain its historical classification.
create or replace function public.m1_protect_published_question_taxonomy()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_question_version_id uuid;
begin
  if tg_op = 'DELETE' then
    v_question_version_id := old.question_version_id;
  else
    v_question_version_id := new.question_version_id;
  end if;

  if exists (
    select 1
    from public.exam_version_questions evq
    join public.exam_versions ev on ev.id = evq.exam_version_id
    where evq.question_version_id = v_question_version_id
      and ev.status = 'published'
  ) then
    raise exception using
      errcode = '23514',
      message = 'Taxonomy cannot be changed after the question version is used in a published exam.';
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$function$;

create trigger question_version_taxonomy_published_guard
before insert or update or delete on public.question_version_taxonomy
for each row execute function public.m1_protect_published_question_taxonomy();

-- Relation types must match the taxonomy node's semantic level.
create or replace function public.m1_validate_question_taxonomy_relation()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_node_type text;
  v_expected_type text;
begin
  select tn.node_type into v_node_type
  from public.taxonomy_nodes tn
  where tn.id = new.taxonomy_node_id;

  v_expected_type := case new.relation_type
    when 'primary_topic' then 'topic'
    when 'secondary_topic' then 'topic'
    when 'skill' then 'skill'
    when 'competency' then 'competency'
  end;

  if v_node_type is distinct from v_expected_type then
    raise exception using
      errcode = '23514',
      message = 'Taxonomy relation type does not match taxonomy node type.';
  end if;
  return new;
end;
$function$;

create trigger question_version_taxonomy_relation_guard
before insert or update on public.question_version_taxonomy
for each row execute function public.m1_validate_question_taxonomy_relation();

-- Stimulus versions are immutable from creation; edits are represented by a new version row.
create or replace function public.m1_reject_stimulus_version_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using
    errcode = '55000',
    message = 'Stimulus versions are immutable; create a new version instead.';
end;
$function$;

create trigger stimulus_versions_immutable
before update or delete on public.stimulus_versions
for each row execute function public.m1_reject_stimulus_version_mutation();

-- Seed only the three canonical subjects. Existing questions are intentionally untouched.
insert into public.subjects(code,name,description,display_order)
values
  ('mathematics','Toán','Đánh giá năng lực tư duy và giải quyết vấn đề toán học.',1),
  ('reading','Đọc hiểu','Đánh giá năng lực đọc, hiểu và xử lý thông tin từ ngữ liệu.',2),
  ('science','Khoa học','Đánh giá năng lực khoa học và vận dụng kiến thức vào bối cảnh.',3)
on conflict (code) do nothing;

-- All five tables are private to administrators at the table layer.
-- Students receive the active-subject catalogue only through the reviewed RPC below.
alter table public.subjects enable row level security;
alter table public.taxonomy_nodes enable row level security;
alter table public.question_version_taxonomy enable row level security;
alter table public.stimuli enable row level security;
alter table public.stimulus_versions enable row level security;

grant select,insert,update,delete on public.subjects,
  public.taxonomy_nodes,public.question_version_taxonomy,
  public.stimuli,public.stimulus_versions to authenticated;

create policy subjects_admin_all on public.subjects
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));
create policy taxonomy_nodes_admin_all on public.taxonomy_nodes
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));
create policy question_version_taxonomy_admin_all on public.question_version_taxonomy
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));
create policy stimuli_admin_all on public.stimuli
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));
create policy stimulus_versions_admin_all on public.stimulus_versions
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create or replace function public.list_active_subjects()
returns table (
  id uuid,
  code text,
  name text,
  description text,
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
  select s.id,s.code,s.name,s.description,s.display_order
  from public.subjects s
  where s.is_active
  order by s.display_order,s.name;
end;
$function$;

revoke all on function public.list_active_subjects() from public,anon;
grant execute on function public.list_active_subjects() to authenticated;

commit;
