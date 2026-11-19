-- Multiple independent shared stimulus groups per exam question.
-- Preserve the legacy single-stimulus column and JSON snapshot for older readers.

begin;

create table public.question_version_stimuli (
  question_version_id uuid not null references public.question_versions(id) on delete cascade,
  stimulus_version_id uuid not null references public.stimulus_versions(id) on delete restrict,
  position integer not null check (position between 1 and 8),
  created_at timestamptz not null default now(),
  primary key (question_version_id, stimulus_version_id),
  unique (question_version_id, position)
);

create index question_version_stimuli_stimulus_version_idx
  on public.question_version_stimuli(stimulus_version_id);

alter table public.question_version_stimuli enable row level security;

revoke all on public.question_version_stimuli from public, anon, authenticated;

create or replace function public.lit_validate_question_media_and_stimulus()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_stimulus_version public.stimulus_versions%rowtype;
  v_stimulus_status text;
  v_id uuid;
  v_ids jsonb;
  v_item jsonb;
  v_ids_normalized jsonb := '[]'::jsonb;
  v_snapshots jsonb := '[]'::jsonb;
  v_first_snapshot jsonb;
  v_position integer := 0;
begin
  if not public.lit_validate_media_manifest(new.content->'media') then
    raise exception using errcode='23514',
      message='Question media manifest is invalid or exceeds the 12-image limit.';
  end if;

  v_ids := new.content->'stimulus_version_ids';
  if jsonb_typeof(v_ids) is distinct from 'array' then
    v_id := coalesce(
      new.stimulus_version_id,
      nullif(new.content->>'stimulus_version_id','')::uuid
    );
    if v_id is null then
      v_ids := '[]'::jsonb;
    else
      v_ids := jsonb_build_array(v_id::text);
    end if;
  end if;

  if jsonb_array_length(v_ids) > 8 then
    raise exception using errcode='23514',
      message='A question may reference at most eight shared stimulus groups.';
  end if;

  for v_item in select value from jsonb_array_elements(v_ids)
  loop
    v_id := (v_item #>> '{}')::uuid;
    if v_id is null then
      raise exception using errcode='23514',
        message='Shared stimulus version IDs must be UUID strings.';
    end if;

    select s.status into v_stimulus_status
    from public.stimulus_versions sv
    join public.stimuli s on s.id=sv.stimulus_id
    where sv.id=v_id;

    if not found or v_stimulus_status='archived' then
      raise exception using errcode='23503',
        message='A selected shared stimulus version does not exist or is archived.';
    end if;

    select sv.* into v_stimulus_version
    from public.stimulus_versions sv
    where sv.id=v_id;

    if not public.lit_validate_media_manifest(v_stimulus_version.content->'media') then
      raise exception using errcode='23514',
        message='Shared stimulus media manifest is invalid.';
    end if;

    v_position := v_position + 1;
    v_ids_normalized := v_ids_normalized || jsonb_build_array(v_id::text);
    v_item := jsonb_build_object(
      'id',v_stimulus_version.stimulus_id,
      'version_id',v_stimulus_version.id,
      'version_no',v_stimulus_version.version_no,
      'type',v_stimulus_version.stimulus_type,
      'content',v_stimulus_version.content,
      'metadata',v_stimulus_version.metadata
    );
    v_snapshots := v_snapshots || jsonb_build_array(v_item);
    if v_position=1 then
      v_first_snapshot := v_item;
    end if;
  end loop;

  new.content := new.content - 'stimulus' - 'stimulus_version_id'
    - 'stimulus_version_ids' - 'stimuli';

  if v_position=0 then
    new.stimulus_version_id := null;
  else
    new.stimulus_version_id := (v_ids_normalized->>0)::uuid;
    new.content := jsonb_set(new.content,'{stimulus_version_ids}',v_ids_normalized,true);
    new.content := jsonb_set(new.content,'{stimuli}',v_snapshots,true);
    -- Compatibility snapshot for existing consumers that understand one group.
    new.content := jsonb_set(new.content,'{stimulus}',v_first_snapshot,true);
  end if;

  return new;
end;
$function$;

create or replace function private.lit_link_question_version_stimuli()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  insert into public.question_version_stimuli(
    question_version_id,stimulus_version_id,position
  )
  select new.id,(item.value #>> '{}')::uuid,item.ordinality::integer
  from jsonb_array_elements(coalesce(new.content->'stimulus_version_ids','[]'::jsonb))
    with ordinality as item(value,ordinality);
  return new;
end;
$function$;

revoke all on function private.lit_link_question_version_stimuli() from public,anon,authenticated;

create trigger question_versions_link_stimulus_groups
after insert on public.question_versions
for each row execute function private.lit_link_question_version_stimuli();

-- Backfill the normalized relation for versions created by the first single-group migration.
insert into public.question_version_stimuli(question_version_id,stimulus_version_id,position)
select qv.id,qv.stimulus_version_id,1
from public.question_versions qv
where qv.stimulus_version_id is not null
on conflict do nothing;

create or replace function private.lit_can_read_question_media(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select auth.uid() is not null
    and exists (
      select 1 from public.profiles p
      where p.id=auth.uid() and p.role='student' and p.status='active'
    )
    and exists (
      select 1
      from public.question_versions qv
      join public.exam_version_questions evq on evq.question_version_id=qv.id
      join public.exam_versions ev on ev.id=evq.exam_version_id
      where ev.status='published'
        and (
          exists (
            select 1
            from jsonb_array_elements(coalesce(qv.content->'media','[]'::jsonb)) media(value)
            where media.value->>'path'=p_path
          )
          or exists (
            select 1
            from jsonb_array_elements(coalesce(qv.content->'stimuli','[]'::jsonb)) stimulus(value)
            cross join lateral jsonb_array_elements(
              coalesce(stimulus.value->'content'->'media','[]'::jsonb)
            ) media(value)
            where media.value->>'path'=p_path
          )
          or exists (
            select 1
            from jsonb_array_elements(
              coalesce(qv.content->'stimulus'->'content'->'media','[]'::jsonb)
            ) media(value)
            where media.value->>'path'=p_path
          )
        )
    );
$function$;

revoke all on function private.lit_can_read_question_media(text) from public,anon;
grant execute on function private.lit_can_read_question_media(text) to authenticated;

commit;
