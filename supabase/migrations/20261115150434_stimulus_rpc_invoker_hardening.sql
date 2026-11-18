-- Keep the shared-stimulus RPC under caller privileges and let existing
-- Admin-only RLS policies protect the stimuli tables.

begin;

create or replace function public.admin_save_stimulus_version(
  p_stimulus_id uuid,
  p_stimulus_type text,
  p_content jsonb,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
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
