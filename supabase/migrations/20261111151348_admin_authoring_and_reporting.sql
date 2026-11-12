-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: undefined

-- Migration 010: secure Admin authoring and reporting RPCs.
-- No legacy exam/solution rows are modified or deleted.

create or replace function public.admin_list_exam_versions()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được xem danh sách quản trị đề thi.';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'exam_id', ev.exam_id,
      'exam_version_id', ev.id,
      'version_no', ev.version_no,
      'title', ev.title,
      'description', ev.description,
      'duration_minutes', ev.duration_minutes,
      'status', ev.status,
      'created_at', ev.created_at,
      'published_at', ev.published_at,
      'question_count', (
        select count(*) from public.exam_version_questions evq
        where evq.exam_version_id = ev.id
      ),
      'attempt_count', (
        select count(*) from public.attempts a
        where a.exam_version_id = ev.id
      )
    ) order by ev.created_at desc
  ), '[]'::jsonb)
  into v_result
  from public.exam_versions ev;

  return v_result;
end;
$function$;

create or replace function public.admin_get_exam_version(p_exam_version_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được xem nội dung quản trị đề thi.';
  end if;

  select jsonb_build_object(
    'exam_id', ev.exam_id,
    'exam_version_id', ev.id,
    'version_no', ev.version_no,
    'title', ev.title,
    'description', ev.description,
    'duration_minutes', ev.duration_minutes,
    'status', ev.status,
    'created_at', ev.created_at,
    'published_at', ev.published_at,
    'questions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'mapping_id', evq.id,
        'question_id', qv.question_id,
        'question_version_id', qv.id,
        'position', evq.position,
        'points', evq.points,
        'type', qv.question_type,
        'content', qv.content,
        'answer_key', ak.answer_key,
        'explanation', ak.explanation,
        'grading_config', ak.grading_config,
        'source_metadata', ak.source_metadata
      ) order by evq.position)
      from public.exam_version_questions evq
      join public.question_versions qv on qv.id = evq.question_version_id
      left join public.question_answer_keys ak on ak.question_version_id = qv.id
      where evq.exam_version_id = ev.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.exam_versions ev
  where ev.id = p_exam_version_id;

  if v_result is null then
    raise exception 'Không tìm thấy phiên bản đề thi.';
  end if;
  return v_result;
end;
$function$;

create or replace function public.admin_save_question(
  p_question_id uuid,
  p_scope text,
  p_owner_exam_id uuid,
  p_question_type text,
  p_content jsonb,
  p_answer_key jsonb,
  p_explanation text,
  p_grading_config jsonb,
  p_source_metadata jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
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
      select coalesce(array_agg((m)[1]::integer order by (m)[1]::integer),array[]::integer[])
      into v_slot_keys
      from regexp_matches(p_content->>'q','\[([0-9]+)\]','g') as x(m);
      select coalesce(array_agg(key::integer order by key::integer),array[]::integer[]),
             coalesce(array_agg(value::integer order by key::integer),array[]::integer[])
      into v_key_slots,v_key_values
      from jsonb_each_text(p_answer_key);
      if cardinality(v_slot_keys) = 0
         or cardinality(v_slot_keys) <> (select count(distinct z) from unnest(v_slot_keys) z)
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
$function$;

create or replace function public.admin_add_question_to_exam(
  p_exam_version_id uuid,
  p_question_version_id uuid,
  p_points numeric
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_exam public.exam_versions%rowtype;
  v_question_id uuid;
  v_mapping_id uuid;
  v_position integer;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được thêm câu hỏi vào đề.';
  end if;
  if p_points is null or p_points <= 0 then
    raise exception 'Điểm câu hỏi phải lớn hơn 0.';
  end if;

  select * into v_exam from public.exam_versions
  where id=p_exam_version_id for update;
  if not found or v_exam.status <> 'draft' then
    raise exception 'Chỉ có thể sửa phiên bản đề ở trạng thái nháp.';
  end if;

  select question_id into v_question_id
  from public.question_versions where id=p_question_version_id;
  if not found then raise exception 'Không tìm thấy phiên bản câu hỏi.'; end if;
  if not exists (
    select 1 from public.question_answer_keys
    where question_version_id=p_question_version_id
  ) then
    raise exception 'Câu hỏi chưa có đáp án chuẩn.';
  end if;

  select coalesce(max(position),0)+1 into v_position
  from public.exam_version_questions where exam_version_id=p_exam_version_id;

  insert into public.exam_version_questions(
    exam_version_id,exam_id,question_version_id,question_id,position,points
  ) values (
    p_exam_version_id,v_exam.exam_id,p_question_version_id,v_question_id,v_position,p_points
  ) returning id into v_mapping_id;
  return v_mapping_id;
end;
$function$;

create or replace function public.admin_remove_question_from_exam(
  p_exam_version_id uuid,
  p_mapping_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare v_exam public.exam_versions%rowtype; v_offset integer;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được xóa câu hỏi khỏi đề.';
  end if;
  select * into v_exam from public.exam_versions
  where id=p_exam_version_id for update;
  if not found or v_exam.status <> 'draft' then
    raise exception 'Chỉ có thể sửa phiên bản đề ở trạng thái nháp.';
  end if;
  if not exists (
    select 1 from public.exam_version_questions
    where id=p_mapping_id and exam_version_id=p_exam_version_id
  ) then raise exception 'Không tìm thấy câu hỏi trong phiên bản đề.'; end if;

  select coalesce(max(position),0)+count(*)+1 into v_offset
  from public.exam_version_questions where exam_version_id=p_exam_version_id;
  delete from public.exam_version_questions
  where id=p_mapping_id and exam_version_id=p_exam_version_id;

  update public.exam_version_questions
  set position=position+v_offset
  where exam_version_id=p_exam_version_id;
  with ranked as (
    select id,row_number() over(order by position)::integer as new_position
    from public.exam_version_questions where exam_version_id=p_exam_version_id
  )
  update public.exam_version_questions evq
  set position=ranked.new_position
  from ranked where evq.id=ranked.id;
  return true;
end;
$function$;

create or replace function public.admin_reorder_exam_questions(
  p_exam_version_id uuid,
  p_mapping_ids uuid[]
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare v_exam public.exam_versions%rowtype; v_count integer; v_offset integer;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được sắp xếp câu hỏi.';
  end if;
  select * into v_exam from public.exam_versions
  where id=p_exam_version_id for update;
  if not found or v_exam.status <> 'draft' then
    raise exception 'Chỉ có thể sửa phiên bản đề ở trạng thái nháp.';
  end if;
  if p_mapping_ids is null then raise exception 'Danh sách thứ tự không hợp lệ.'; end if;

  select count(*) into v_count from public.exam_version_questions
  where exam_version_id=p_exam_version_id;
  if cardinality(p_mapping_ids) <> v_count
     or cardinality(p_mapping_ids) <> (
       select count(distinct x) from unnest(p_mapping_ids) x
     )
     or exists (
       select 1 from unnest(p_mapping_ids) x
       where not exists (
         select 1 from public.exam_version_questions evq
         where evq.id=x and evq.exam_version_id=p_exam_version_id
       )
     ) then
    raise exception 'Danh sách phải chứa mỗi câu hỏi trong đề đúng một lần.';
  end if;

  select coalesce(max(position),0)+v_count+1 into v_offset
  from public.exam_version_questions where exam_version_id=p_exam_version_id;
  update public.exam_version_questions
  set position=position+v_offset
  where exam_version_id=p_exam_version_id;

  update public.exam_version_questions evq
  set position=ordered.ordinality::integer
  from unnest(p_mapping_ids) with ordinality as ordered(id,ordinality)
  where evq.id=ordered.id and evq.exam_version_id=p_exam_version_id;
  return true;
end;
$function$;

create or replace function public.admin_update_exam_version(
  p_exam_version_id uuid,
  p_title text,
  p_description text,
  p_duration_minutes integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được sửa thông tin đề thi.';
  end if;
  if nullif(btrim(p_title),'') is null or char_length(btrim(p_title)) > 240
     or p_duration_minutes is null or p_duration_minutes < 1 or p_duration_minutes > 600 then
    raise exception 'Tên đề hoặc thời lượng không hợp lệ.';
  end if;
  update public.exam_versions
  set title=btrim(p_title),description=coalesce(p_description,''),duration_minutes=p_duration_minutes
  where id=p_exam_version_id and status='draft';
  if not found then raise exception 'Không tìm thấy phiên bản nháp để cập nhật.'; end if;
  return true;
end;
$function$;

create or replace function public.admin_list_profiles(p_limit integer default 100,p_offset integer default 0)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được xem danh sách tài khoản.';
  end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
  into v_result
  from (
    select id,email,display_name,user_code,role,status,created_at,updated_at
    from public.profiles order by created_at desc
    limit greatest(1,least(coalesce(p_limit,100),200))
    offset greatest(coalesce(p_offset,0),0)
  ) x;
  return v_result;
end;
$function$;

create or replace function public.admin_list_attempts(p_limit integer default 100,p_offset integer default 0)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được xem lịch sử làm bài.';
  end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.started_at desc),'[]'::jsonb)
  into v_result
  from (
    select a.id,a.user_id,p.user_code,p.display_name,p.email,
      a.exam_id,a.exam_version_id,ev.title,ev.version_no,
      a.status,a.score,a.max_score,a.elapsed_seconds,
      a.started_at,a.finished_at,a.submitted_at,a.result_details
    from public.attempts a
    join public.profiles p on p.id=a.user_id
    left join public.exam_versions ev on ev.id=a.exam_version_id
    order by a.started_at desc
    limit greatest(1,least(coalesce(p_limit,100),200))
    offset greatest(coalesce(p_offset,0),0)
  ) x;
  return v_result;
end;
$function$;

revoke all on function public.admin_list_exam_versions() from public,anon;
revoke all on function public.admin_get_exam_version(uuid) from public,anon;
revoke all on function public.admin_save_question(uuid,text,uuid,text,jsonb,jsonb,text,jsonb,jsonb) from public,anon;
revoke all on function public.admin_add_question_to_exam(uuid,uuid,numeric) from public,anon;
revoke all on function public.admin_remove_question_from_exam(uuid,uuid) from public,anon;
revoke all on function public.admin_reorder_exam_questions(uuid,uuid[]) from public,anon;
revoke all on function public.admin_update_exam_version(uuid,text,text,integer) from public,anon;
revoke all on function public.admin_list_profiles(integer,integer) from public,anon;
revoke all on function public.admin_list_attempts(integer,integer) from public,anon;

grant execute on function public.admin_list_exam_versions() to authenticated;
grant execute on function public.admin_get_exam_version(uuid) to authenticated;
grant execute on function public.admin_save_question(uuid,text,uuid,text,jsonb,jsonb,text,jsonb,jsonb) to authenticated;
grant execute on function public.admin_add_question_to_exam(uuid,uuid,numeric) to authenticated;
grant execute on function public.admin_remove_question_from_exam(uuid,uuid) to authenticated;
grant execute on function public.admin_reorder_exam_questions(uuid,uuid[]) to authenticated;
grant execute on function public.admin_update_exam_version(uuid,text,text,integer) to authenticated;
grant execute on function public.admin_list_profiles(integer,integer) to authenticated;
grant execute on function public.admin_list_attempts(integer,integer) to authenticated;
