-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: eae7b4caa2a3c4be8b148667e6d3adc8

-- Migration 013: atomic Admin save of an entire draft exam.
-- A failed question validation rolls back the whole save.

create or replace function public.admin_save_exam_content(
  p_exam_version_id uuid,
  p_title text,
  p_description text,
  p_duration_minutes integer,
  p_questions jsonb,
  p_publish boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_exam_version_id uuid := p_exam_version_id;
  v_exam_id uuid;
  v_status text;
  v_item jsonb;
  v_question_version_id uuid;
  v_mapping_id uuid;
  v_points numeric;
  v_scope text;
  v_owner_exam_id uuid;
  v_question_id uuid;
  v_keep_mapping_ids uuid[] := array[]::uuid[];
  v_removed integer := 0;
  v_count integer := 0;
  v_publish_result jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được lưu đề thi.';
  end if;
  if nullif(btrim(p_title),'') is null or char_length(btrim(p_title))>240
     or p_duration_minutes is null or p_duration_minutes<1 or p_duration_minutes>600 then
    raise exception 'Tên đề hoặc thời lượng không hợp lệ.';
  end if;
  if jsonb_typeof(p_questions)<>'array' or jsonb_array_length(p_questions)=0 then
    raise exception 'Đề thi phải có ít nhất một câu hỏi.';
  end if;
  if jsonb_array_length(p_questions)>200 then
    raise exception 'Mỗi đề thi không được vượt quá 200 câu.';
  end if;

  if v_exam_version_id is null then
    v_exam_version_id := public.admin_create_exam(p_title,p_description,p_duration_minutes);
  end if;

  select exam_id,status into v_exam_id,v_status
  from public.exam_versions where id=v_exam_version_id for update;
  if not found or v_status<>'draft' then
    raise exception 'Chỉ có thể lưu phiên bản đề ở trạng thái nháp.';
  end if;

  update public.exam_versions
  set title=btrim(p_title),description=coalesce(p_description,''),
      duration_minutes=p_duration_minutes
  where id=v_exam_version_id;

  for v_item in select value from jsonb_array_elements(p_questions)
  loop
    v_count := v_count+1;
    v_mapping_id := nullif(v_item->>'mapping_id','')::uuid;
    v_question_id := nullif(v_item->>'question_id','')::uuid;
    v_scope := coalesce(v_item->>'scope','exam');
    v_owner_exam_id := case
      when v_scope='exam' then coalesce(nullif(v_item->>'owner_exam_id','')::uuid,v_exam_id)
      else null
    end;
    v_points := coalesce((v_item->>'points')::numeric,1);

    if v_mapping_id is not null then
      if v_mapping_id=any(v_keep_mapping_ids) then
        raise exception 'Một câu hỏi xuất hiện lặp trong dữ liệu lưu.';
      end if;
      v_keep_mapping_ids := array_append(v_keep_mapping_ids,v_mapping_id);
    end if;

    v_question_version_id := public.admin_save_question(
      v_question_id,
      v_scope,
      v_owner_exam_id,
      v_item->>'type',
      v_item->'content',
      v_item->'answer_key',
      coalesce(v_item->>'explanation',''),
      coalesce(v_item->'grading_config','{}'::jsonb),
      coalesce(v_item->'source_metadata','{}'::jsonb)
    );

    if v_mapping_id is not null then
      perform public.admin_replace_question_in_exam(
        v_exam_version_id,v_mapping_id,v_question_version_id,v_points
      );
    else
      perform public.admin_add_question_to_exam(
        v_exam_version_id,v_question_version_id,v_points
      );
    end if;
  end loop;

  delete from public.exam_version_questions evq
  where evq.exam_version_id=v_exam_version_id
    and not (evq.id=any(v_keep_mapping_ids))
    and not exists (
      select 1 from jsonb_array_elements(p_questions) x(value)
      where nullif(x.value->>'mapping_id','')::uuid=evq.id
    );
  get diagnostics v_removed=row_count;

  if p_publish then
    v_publish_result := public.admin_publish_exam_version(v_exam_version_id);
  else
    v_publish_result := jsonb_build_object('success',false,'status','draft');
  end if;

  return jsonb_build_object(
    'success',true,
    'exam_id',v_exam_id,
    'exam_version_id',v_exam_version_id,
    'question_count',v_count,
    'removed_question_count',v_removed,
    'published',coalesce(p_publish,false),
    'publish_result',v_publish_result
  );
end;
$function$;

revoke all on function public.admin_save_exam_content(uuid,text,text,integer,jsonb,boolean) from public,anon;
grant execute on function public.admin_save_exam_content(uuid,text,text,integer,jsonb,boolean) to authenticated;
