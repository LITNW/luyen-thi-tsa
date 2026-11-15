-- Question-local image media and reusable, version-pinned stimulus groups.
-- Additive only: legacy question payloads and published exam snapshots remain valid.

begin;

alter table public.question_versions
  add column stimulus_version_id uuid null
  references public.stimulus_versions(id) on delete restrict;

create index question_versions_stimulus_version_id_idx
  on public.question_versions(stimulus_version_id)
  where stimulus_version_id is not null;

create or replace function public.lit_validate_media_manifest(p_media jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $function$
declare
  v_item jsonb;
begin
  if p_media is null then
    return true;
  end if;
  if jsonb_typeof(p_media) <> 'array' then
    return false;
  end if;
  if jsonb_array_length(p_media) > 12 then
    return false;
  end if;

  for v_item in select value from jsonb_array_elements(p_media)
  loop
    if jsonb_typeof(v_item) <> 'object'
       or nullif(btrim(v_item->>'path'),'') is null
       or (v_item->>'path') not like 'question-media/%'
       or length(coalesce(v_item->>'alt','')) > 300
       or length(coalesce(v_item->>'caption','')) > 500 then
      return false;
    end if;
  end loop;
  return true;
end;
$function$;

create or replace function public.lit_validate_question_media_and_stimulus()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_stimulus_version public.stimulus_versions%rowtype;
  v_stimulus_status text;
  v_id uuid;
begin
  if not public.lit_validate_media_manifest(new.content->'media') then
    raise exception using errcode='23514',
      message='Question media manifest is invalid or exceeds the 12-image limit.';
  end if;

  v_id := coalesce(
    new.stimulus_version_id,
    nullif(new.content->>'stimulus_version_id','')::uuid
  );

  if v_id is null then
    new.stimulus_version_id := null;
    new.content := new.content - 'stimulus_version_id' - 'stimulus';
    return new;
  end if;

  select s.status into v_stimulus_status
  from public.stimulus_versions sv
  join public.stimuli s on s.id=sv.stimulus_id
  where sv.id=v_id;

  if not found or v_stimulus_status='archived' then
    raise exception using errcode='23503',
      message='The selected shared stimulus version does not exist or is archived.';
  end if;

  select sv.* into v_stimulus_version
  from public.stimulus_versions sv
  where sv.id=v_id;

  if not public.lit_validate_media_manifest(v_stimulus_version.content->'media') then
    raise exception using errcode='23514',
      message='Shared stimulus media manifest is invalid.';
  end if;

  new.stimulus_version_id := v_id;
  new.content := jsonb_set(
    new.content - 'stimulus',
    '{stimulus_version_id}',
    to_jsonb(v_id::text),
    true
  );
  new.content := jsonb_set(
    new.content,
    '{stimulus}',
    jsonb_build_object(
      'id',v_stimulus_version.stimulus_id,
      'version_id',v_stimulus_version.id,
      'version_no',v_stimulus_version.version_no,
      'type',v_stimulus_version.stimulus_type,
      'content',v_stimulus_version.content,
      'metadata',v_stimulus_version.metadata
    ),
    true
  );
  return new;
end;
$function$;

create trigger question_versions_attach_stimulus_snapshot
before insert on public.question_versions
for each row execute function public.lit_validate_question_media_and_stimulus();

create or replace function public.lit_validate_stimulus_media()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if not public.lit_validate_media_manifest(new.content->'media') then
    raise exception using errcode='23514',
      message='Shared stimulus media manifest is invalid or exceeds the 12-image limit.';
  end if;
  return new;
end;
$function$;

create trigger stimulus_versions_validate_media
before insert on public.stimulus_versions
for each row execute function public.lit_validate_stimulus_media();

-- Private bucket: authenticated Admins upload; students can read only assets referenced
-- by a published question version. The existing tsa-imports bucket is untouched.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values (
  'lit-question-media',
  'lit-question-media',
  false,
  10485760,
  array['image/jpeg','image/png','image/webp','image/gif']
)
on conflict (id) do nothing;

drop policy if exists lit_question_media_admin_insert on storage.objects;
create policy lit_question_media_admin_insert
on storage.objects for insert to authenticated
with check (
  bucket_id='lit-question-media'
  and (select public.is_admin())
  and name like 'question-media/%'
);

drop policy if exists lit_question_media_admin_update on storage.objects;
create policy lit_question_media_admin_update
on storage.objects for update to authenticated
using (bucket_id='lit-question-media' and (select public.is_admin()))
with check (bucket_id='lit-question-media' and (select public.is_admin()));

drop policy if exists lit_question_media_admin_delete on storage.objects;
create policy lit_question_media_admin_delete
on storage.objects for delete to authenticated
using (bucket_id='lit-question-media' and (select public.is_admin()));

create or replace function public.lit_can_read_question_media(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select auth.uid() is not null
    and exists (
      select 1 from public.profiles p
      where p.id=auth.uid() and p.status='active'
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
            from jsonb_array_elements(
              coalesce(qv.content->'stimulus'->'content'->'media','[]'::jsonb)
            ) media(value)
            where media.value->>'path'=p_path
          )
        )
    );
$function$;

revoke all on function public.lit_can_read_question_media(text) from public,anon;
grant execute on function public.lit_can_read_question_media(text) to authenticated;

drop policy if exists lit_question_media_read_published on storage.objects;
create policy lit_question_media_read_published
on storage.objects for select to authenticated
using (
  bucket_id='lit-question-media'
  and (
    (select public.is_admin())
    or (select public.lit_can_read_question_media(name))
  )
);

create or replace function public.admin_save_stimulus_version(
  p_stimulus_id uuid,
  p_stimulus_type text,
  p_content jsonb,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_stimulus_id uuid;
  v_version_id uuid;
  v_version_no integer;
  v_status text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only an active Admin may save shared stimulus material.';
  end if;
  if p_stimulus_type is null or p_stimulus_type not in ('text','table','chart','image','dataset','experiment','mixed') then
    raise exception 'Unsupported shared stimulus type.';
  end if;
  if p_content is null or jsonb_typeof(p_content)<>'object'
     or not public.lit_validate_media_manifest(p_content->'media')
     or p_metadata is null or jsonb_typeof(p_metadata)<>'object' then
    raise exception 'Shared stimulus content or metadata is invalid.';
  end if;

  if p_stimulus_id is null then
    insert into public.stimuli(status,created_by)
    values ('draft',auth.uid())
    returning id into v_stimulus_id;
  else
    select status into v_status
    from public.stimuli
    where id=p_stimulus_id
    for update;
    if not found or v_status='archived' then
      raise exception 'Shared stimulus does not exist or is archived.';
    end if;
    v_stimulus_id := p_stimulus_id;
  end if;

  select coalesce(max(version_no),0)+1
    into v_version_no
  from public.stimulus_versions
  where stimulus_id=v_stimulus_id;

  insert into public.stimulus_versions(
    stimulus_id,version_no,stimulus_type,content,metadata,created_by
  ) values (
    v_stimulus_id,v_version_no,p_stimulus_type,p_content,p_metadata,auth.uid()
  ) returning id into v_version_id;

  return jsonb_build_object(
    'stimulus_id',v_stimulus_id,
    'stimulus_version_id',v_version_id,
    'version_no',v_version_no
  );
end;
$function$;

revoke all on function public.admin_save_stimulus_version(uuid,text,jsonb,jsonb) from public,anon;
grant execute on function public.admin_save_stimulus_version(uuid,text,jsonb,jsonb) to authenticated;

commit;
