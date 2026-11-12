-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: 6f08516fc3e6f1bcb887b4486d786e81

-- Migration 011: safe replacement of draft question mappings and question-bank lookup.

create or replace function public.admin_replace_question_in_exam(
  p_exam_version_id uuid,
  p_mapping_id uuid,
  p_question_version_id uuid,
  p_points numeric
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_exam public.exam_versions%rowtype;
  v_question_id uuid;
  v_scope text;
  v_owner_exam_id uuid;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được thay câu hỏi trong đề.';
  end if;
  if p_points is null or p_points <= 0 then
    raise exception 'Điểm câu hỏi phải lớn hơn 0.';
  end if;

  select * into v_exam from public.exam_versions
  where id=p_exam_version_id for update;
  if not found or v_exam.status <> 'draft' then
    raise exception 'Chỉ có thể sửa phiên bản đề ở trạng thái nháp.';
  end if;
  if not exists (
    select 1 from public.exam_version_questions
    where id=p_mapping_id and exam_version_id=p_exam_version_id
  ) then raise exception 'Không tìm thấy câu hỏi cần thay.'; end if;

  select qv.question_id,q.scope,q.owner_exam_id
  into v_question_id,v_scope,v_owner_exam_id
  from public.question_versions qv
  join public.questions q on q.id=qv.question_id
  where qv.id=p_question_version_id;
  if not found then raise exception 'Không tìm thấy phiên bản câu hỏi mới.'; end if;
  if v_scope='exam' and v_owner_exam_id is distinct from v_exam.exam_id then
    raise exception 'Câu hỏi thuộc một đề thi khác.';
  end if;
  if not exists (
    select 1 from public.question_answer_keys
    where question_version_id=p_question_version_id
  ) then raise exception 'Câu hỏi mới chưa có đáp án chuẩn.'; end if;
  if exists (
    select 1 from public.exam_version_questions
    where exam_version_id=p_exam_version_id
      and question_version_id=p_question_version_id
      and id<>p_mapping_id
  ) then raise exception 'Phiên bản câu hỏi này đã có trong đề.'; end if;

  update public.exam_version_questions
  set question_version_id=p_question_version_id,
      question_id=v_question_id,
      points=p_points
  where id=p_mapping_id and exam_version_id=p_exam_version_id;
  return true;
end;
$function$;

create or replace function public.admin_update_question_points(
  p_exam_version_id uuid,
  p_mapping_id uuid,
  p_points numeric
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare v_status text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được sửa điểm câu hỏi.';
  end if;
  if p_points is null or p_points <= 0 then
    raise exception 'Điểm câu hỏi phải lớn hơn 0.';
  end if;
  select status into v_status from public.exam_versions
  where id=p_exam_version_id for update;
  if not found or v_status<>'draft' then
    raise exception 'Chỉ có thể sửa phiên bản đề ở trạng thái nháp.';
  end if;
  update public.exam_version_questions
  set points=p_points
  where id=p_mapping_id and exam_version_id=p_exam_version_id;
  if not found then raise exception 'Không tìm thấy câu hỏi trong đề.'; end if;
  return true;
end;
$function$;

create or replace function public.admin_list_question_bank(
  p_search text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được xem ngân hàng câu hỏi.';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
  into v_result
  from (
    select q.id as question_id,q.scope,q.owner_exam_id,q.created_at,
      qv.id as question_version_id,qv.version_no,qv.question_type,qv.content,
      ak.answer_key,ak.explanation,ak.grading_config,ak.source_metadata
    from public.questions q
    join lateral (
      select qv0.* from public.question_versions qv0
      where qv0.question_id=q.id
      order by qv0.version_no desc limit 1
    ) qv on true
    left join public.question_answer_keys ak on ak.question_version_id=qv.id
    where q.scope='bank'
      and (
        nullif(btrim(coalesce(p_search,'')),'') is null
        or qv.content->>'q' ilike '%'||btrim(p_search)||'%'
      )
    order by q.created_at desc
    limit greatest(1,least(coalesce(p_limit,100),200))
    offset greatest(coalesce(p_offset,0),0)
  ) x;
  return v_result;
end;
$function$;

revoke all on function public.admin_replace_question_in_exam(uuid,uuid,uuid,numeric) from public,anon;
revoke all on function public.admin_update_question_points(uuid,uuid,numeric) from public,anon;
revoke all on function public.admin_list_question_bank(text,integer,integer) from public,anon;
grant execute on function public.admin_replace_question_in_exam(uuid,uuid,uuid,numeric) to authenticated;
grant execute on function public.admin_update_question_points(uuid,uuid,numeric) to authenticated;
grant execute on function public.admin_list_question_bank(text,integer,integer) to authenticated;
