-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: d2e7b574da5c4068b6d930c126b982af
CREATE OR REPLACE FUNCTION public.admin_save_question(p_question_id uuid, p_scope text, p_owner_exam_id uuid, p_question_type text, p_content jsonb, p_answer_key jsonb, p_explanation text, p_grading_config jsonb, p_source_metadata jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_question_id uuid;
  v_question_version_id uuid;
  v_existing public.questions%rowtype;
  v_version_no integer;
  v_option_count integer;
  v_slot_keys integer[];
  v_key_slots integer[];
  v_key_values integer[];
  v_count integer;
  v_distinct integer;
  v_valid boolean;
  v_num numeric;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được tạo hoặc cập nhật câu hỏi.';
  end if;

  if p_scope not in ('bank','exam')
     or (p_scope = 'bank' and p_owner_exam_id is not null)
     or (p_scope = 'exam' and p_owner_exam_id is null) then
    raise exception 'Phạm vi câu hỏi không hợp lệ.';
  end if;
  if p_scope = 'exam' and not exists (
    select 1 from public.exams e where e.id = p_owner_exam_id
  ) then
    raise exception 'Đề sở hữu câu hỏi không tồn tại.';
  end if;

  if p_question_type not in ('mc','ms','tf','num','dnd') then
    raise exception 'Loại câu hỏi không được hỗ trợ.';
  end if;
  if p_content is null
     or jsonb_typeof(p_content) <> 'object'
     or jsonb_typeof(p_content->'q') <> 'string'
     or nullif(btrim(p_content->>'q'),'') is null
     or jsonb_typeof(p_content->'o') <> 'array' then
    raise exception 'Nội dung câu hỏi phải có đề bài và mảng phương án.';
  end if;
  if p_content ?| array['a','answer','answer_key','e','explanation','fm'] then
    raise exception 'Không được đưa đáp án, lời giải hoặc metadata đáp án vào nội dung công khai.';
  end if;
  if jsonb_typeof(p_answer_key) is null or p_answer_key = 'null'::jsonb then
    raise exception 'Đáp án không được để trống.';
  end if;

  v_option_count := jsonb_array_length(p_content->'o');
  if exists (
    select 1 from jsonb_array_elements(p_content->'o') x(value)
    where jsonb_typeof(value) <> 'string'
  ) then
    raise exception 'Mỗi phương án phải là chuỗi văn bản.';
  end if;

  case p_question_type
    when 'mc' then
      if jsonb_typeof(p_answer_key) <> 'number' then
        raise exception 'Đáp án MC phải là chỉ số phương án.';
      end if;
      v_num := (p_answer_key #>> '{}')::numeric;
      if v_num <> trunc(v_num) or v_num < 0 or v_num >= v_option_count then
        raise exception 'Chỉ số đáp án MC không hợp lệ.';
      end if;
    when 'ms' then
      if jsonb_typeof(p_answer_key) <> 'array' then
        raise exception 'Đáp án MS phải là mảng chỉ số phương án.';
      end if;
      select count(*), count(distinct value::integer),
        coalesce(bool_and(value ~ '^[0-9]+$' and value::integer between 0 and v_option_count-1),true)
      into v_count,v_distinct,v_valid
      from jsonb_array_elements_text(p_answer_key) x(value);
      if not v_valid or v_count = 0 or v_count <> v_distinct then
        raise exception 'Đáp án MS không hợp lệ.';
      end if;
    when 'tf' then
      if jsonb_typeof(p_answer_key) <> 'array'
         or jsonb_array_length(p_answer_key) <> v_option_count
         or exists (
           select 1 from jsonb_array_elements(p_answer_key) x(value)
           where jsonb_typeof(value) <> 'boolean'
         ) then
        raise exception 'Đáp án TF phải có một giá trị đúng/sai cho mỗi ý.';
      end if;
    when 'num' then
      if jsonb_typeof(p_answer_key) <> 'number' then
        raise exception 'Đáp án NUM phải là số.';
      end if;
    when 'dnd' then
      if jsonb_typeof(p_answer_key) <> 'object' then
        raise exception 'Đáp án DND phải là đối tượng ánh xạ vị trí.';
      end if;
      select coalesce(array_agg(distinct (m)[1]::integer order by (m)[1]::integer),array[]::integer[])
      into v_slot_keys
      from regexp_matches(p_content->>'q','\[([0-9]+)\]','g') as x(m);
      select coalesce(array_agg(key::integer order by key::integer),array[]::integer[]),
             coalesce(array_agg(value::integer order by key::integer),array[]::integer[])
      into v_key_slots,v_key_values
      from jsonb_each_text(p_answer_key);
      if cardinality(v_slot_keys) = 0
         or v_key_slots is distinct from v_slot_keys
         or cardinality(v_key_values) <> cardinality(v_slot_keys)
         or exists (
           select 1 from jsonb_each(p_answer_key) e
           where e.key !~ '^[1-9][0-9]*$'
              or jsonb_typeof(e.value) <> 'number'
              or (e.value #>> '{}') !~ '^[0-9]+$'
              or (e.value #>> '{}')::integer < 1
              or (e.value #>> '{}')::integer > v_option_count
         )
         or cardinality(v_key_values) <> (
           select count(distinct z) from unnest(v_key_values) z
         ) then
        raise exception 'Đáp án DND phải khớp mọi vị trí, dùng chỉ số phương án hợp lệ và không tái sử dụng phương án.';
      end if;
  end case;

  if p_question_id is null then
    insert into public.questions(scope,owner_exam_id,created_by)
    values (p_scope,p_owner_exam_id,auth.uid())
    returning id into v_question_id;
  else
    select * into v_existing
    from public.questions q
    where q.id = p_question_id
    for update;
    if not found then
      raise exception 'Không tìm thấy câu hỏi cần cập nhật.';
    end if;
    if v_existing.scope <> p_scope
       or v_existing.owner_exam_id is distinct from p_owner_exam_id then
      raise exception 'Không được thay đổi phạm vi hoặc đề sở hữu của câu hỏi.';
    end if;
    v_question_id := p_question_id;
  end if;

  select coalesce(max(qv.version_no),0)+1
  into v_version_no
  from public.question_versions qv
  where qv.question_id = v_question_id;

  insert into public.question_versions(
    question_id,version_no,question_type,content,created_by
  ) values (
    v_question_id,v_version_no,p_question_type,p_content,auth.uid()
  ) returning id into v_question_version_id;

  insert into public.question_answer_keys(
    question_version_id,answer_key,explanation,grading_config,source_metadata
  ) values (
    v_question_version_id,p_answer_key,coalesce(p_explanation,''),
    coalesce(p_grading_config,'{}'::jsonb),coalesce(p_source_metadata,'{}'::jsonb)
  );

  return v_question_version_id;
end;
$function$
