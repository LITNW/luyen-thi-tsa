-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: 4ae7b11964bd03dc48e44dcf58e63818

begin;

create or replace function public.admin_create_exam(
  p_title text,
  p_description text default '',
  p_duration_minutes integer default 60
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_exam_id uuid;
  v_version_id uuid;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được tạo đề thi.';
  end if;
  if nullif(btrim(p_title), '') is null or char_length(btrim(p_title)) > 240 then
    raise exception 'Tên đề phải có từ 1 đến 240 ký tự.';
  end if;
  if p_duration_minutes < 1 or p_duration_minutes > 600 then
    raise exception 'Thời lượng phải từ 1 đến 600 phút.';
  end if;

  insert into public.exams(title, description, duration_minutes, questions_public, is_published, created_by)
  values (btrim(p_title), coalesce(p_description,''), p_duration_minutes, '[]'::jsonb, false, auth.uid())
  returning id into v_exam_id;

  insert into public.exam_versions(
    exam_id, version_no, title, description, duration_minutes, status, created_by
  )
  values (
    v_exam_id, 1, btrim(p_title), coalesce(p_description,''), p_duration_minutes, 'draft', auth.uid()
  )
  returning id into v_version_id;

  return v_version_id;
end;
$function$;

create or replace function public.admin_create_exam_version(p_exam_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_source public.exam_versions%rowtype;
  v_new_version_id uuid;
  v_next_version integer;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được tạo phiên bản đề.';
  end if;

  perform 1 from public.exams e where e.id = p_exam_id for update;
  if not found then
    raise exception 'Không tìm thấy đề thi.';
  end if;

  select * into v_source
  from public.exam_versions ev
  where ev.exam_id = p_exam_id
  order by ev.version_no desc
  limit 1;

  if not found then
    raise exception 'Đề thi chưa có phiên bản nguồn.';
  end if;

  select coalesce(max(ev.version_no),0)+1 into v_next_version
  from public.exam_versions ev
  where ev.exam_id = p_exam_id;

  insert into public.exam_versions(
    exam_id, version_no, title, description, duration_minutes, status, created_by
  )
  values (
    p_exam_id, v_next_version, v_source.title, v_source.description,
    v_source.duration_minutes, 'draft', auth.uid()
  )
  returning id into v_new_version_id;

  insert into public.exam_version_questions(
    exam_version_id, exam_id, question_version_id, question_id, position, points
  )
  select v_new_version_id, evq.exam_id, evq.question_version_id,
         evq.question_id, evq.position, evq.points
  from public.exam_version_questions evq
  where evq.exam_version_id = v_source.id
  order by evq.position;

  return v_new_version_id;
end;
$function$;

create or replace function public.admin_set_question_answer_key(
  p_question_version_id uuid,
  p_answer_key jsonb,
  p_explanation text default '',
  p_grading_config jsonb default '{}'::jsonb,
  p_source_metadata jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_type text;
  v_existing public.question_answer_keys%rowtype;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được thiết lập đáp án.';
  end if;
  if p_answer_key is null then
    raise exception 'Đáp án không được để trống.';
  end if;

  select qv.question_type into v_type
  from public.question_versions qv
  where qv.id = p_question_version_id;
  if not found then
    raise exception 'Không tìm thấy phiên bản câu hỏi.';
  end if;

  if exists (
    select 1
    from public.exam_version_questions evq
    join public.exam_versions ev on ev.id = evq.exam_version_id
    where evq.question_version_id = p_question_version_id
      and ev.status = 'published'
  ) then
    raise exception 'Không thể thay đổi đáp án của câu hỏi đã được xuất bản.';
  end if;

  if (v_type = 'mc' and jsonb_typeof(p_answer_key) <> 'number')
     or (v_type = 'tf' and jsonb_typeof(p_answer_key) <> 'array')
     or (v_type = 'num' and jsonb_typeof(p_answer_key) <> 'number')
     or (v_type = 'dnd' and jsonb_typeof(p_answer_key) <> 'object')
     or (v_type = 'ms' and jsonb_typeof(p_answer_key) <> 'array') then
    raise exception 'Kiểu dữ liệu đáp án không khớp loại câu hỏi (%).', v_type;
  end if;

  select * into v_existing
  from public.question_answer_keys ak
  where ak.question_version_id = p_question_version_id;

  if found then
    if v_existing.answer_key = p_answer_key
       and v_existing.explanation = coalesce(p_explanation,'')
       and v_existing.grading_config = coalesce(p_grading_config,'{}'::jsonb)
       and v_existing.source_metadata = coalesce(p_source_metadata,'{}'::jsonb) then
      return false;
    end if;
    raise exception 'Đáp án của phiên bản câu hỏi đã tồn tại và bất biến. Hãy tạo phiên bản câu hỏi mới.';
  end if;

  insert into public.question_answer_keys(
    question_version_id, answer_key, explanation, grading_config, source_metadata
  )
  values (
    p_question_version_id, p_answer_key, coalesce(p_explanation,''),
    coalesce(p_grading_config,'{}'::jsonb), coalesce(p_source_metadata,'{}'::jsonb)
  );

  return true;
end;
$function$;

create or replace function public.admin_publish_exam_version(p_exam_version_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_exam public.exam_versions%rowtype;
  v_total integer;
  v_missing integer;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được xuất bản đề thi.';
  end if;

  select * into v_exam
  from public.exam_versions ev
  where ev.id = p_exam_version_id
  for update;

  if not found then
    raise exception 'Không tìm thấy phiên bản đề thi.';
  end if;
  if v_exam.status <> 'draft' then
    raise exception 'Chỉ phiên bản nháp mới có thể xuất bản.';
  end if;

  select count(*),
         count(*) filter (where ak.question_version_id is null)
    into v_total, v_missing
  from public.exam_version_questions evq
  left join public.question_answer_keys ak
    on ak.question_version_id = evq.question_version_id
  where evq.exam_version_id = p_exam_version_id;

  if v_total = 0 then
    raise exception 'Đề thi chưa có câu hỏi.';
  end if;
  if v_missing > 0 then
    raise exception 'Còn % câu hỏi chưa có đáp án.', v_missing;
  end if;

  update public.exam_versions
  set status = 'published',
      published_by = auth.uid(),
      published_at = pg_catalog.now()
  where id = p_exam_version_id;

  return jsonb_build_object(
    'success', true,
    'exam_version_id', p_exam_version_id,
    'question_count', v_total,
    'published_at', pg_catalog.now()
  );
end;
$function$;

revoke all on function public.admin_create_exam(text,text,integer) from public, anon;
revoke all on function public.admin_create_exam_version(uuid) from public, anon;
revoke all on function public.admin_set_question_answer_key(uuid,jsonb,text,jsonb,jsonb) from public, anon;
revoke all on function public.admin_publish_exam_version(uuid) from public, anon;

grant execute on function public.admin_create_exam(text,text,integer) to authenticated;
grant execute on function public.admin_create_exam_version(uuid) to authenticated;
grant execute on function public.admin_set_question_answer_key(uuid,jsonb,text,jsonb,jsonb) to authenticated;
grant execute on function public.admin_publish_exam_version(uuid) to authenticated;

commit;
