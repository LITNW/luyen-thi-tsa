-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: 41f35a2042aca6571273664fb4a3e7bd

-- Migration 012: add owner-safe attempt resume/history and richer Admin editor payload.

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
        'scope', q.scope,
        'owner_exam_id', q.owner_exam_id,
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
      join public.questions q on q.id=qv.question_id
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

create or replace function public.get_my_attempt_state(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_attempt public.attempts%rowtype;
  v_duration integer;
  v_result jsonb;
begin
  if v_uid is null then raise exception 'Bạn cần đăng nhập.'; end if;
  if not exists (
    select 1 from public.profiles p
    where p.id=v_uid and p.status='active'
  ) then raise exception 'Tài khoản không hoạt động.'; end if;

  select * into v_attempt
  from public.attempts a
  where a.id=p_attempt_id and a.user_id=v_uid
  for update;
  if not found then raise exception 'Không tìm thấy lần làm bài của tài khoản này.'; end if;

  select ev.duration_minutes into v_duration
  from public.exam_versions ev where ev.id=v_attempt.exam_version_id;

  select jsonb_build_object(
    'attempt_id',v_attempt.id,
    'exam_version_id',v_attempt.exam_version_id,
    'status',v_attempt.status,
    'started_at',v_attempt.started_at,
    'finished_at',v_attempt.finished_at,
    'duration_minutes',v_duration,
    'elapsed_seconds',v_attempt.elapsed_seconds,
    'answers',coalesce((
      select jsonb_agg(jsonb_build_object(
        'exam_version_question_id',aa.exam_version_question_id,
        'answer',aa.answer
      ))
      from public.attempt_answers aa where aa.attempt_id=v_attempt.id
    ),'[]'::jsonb),
    'question_times',coalesce((
      select jsonb_agg(jsonb_build_object(
        'exam_version_question_id',t.exam_version_question_id,
        'seconds_spent',t.seconds_spent,
        'visit_count',t.visit_count
      ))
      from public.attempt_question_times t where t.attempt_id=v_attempt.id
    ),'[]'::jsonb),
    'result_details',case when v_attempt.status='submitted' then v_attempt.result_details else null end,
    'score',case when v_attempt.status='submitted' then v_attempt.score else null end,
    'max_score',case when v_attempt.status='submitted' then v_attempt.max_score else null end
  ) into v_result;
  return v_result;
end;
$function$;

create or replace function public.get_my_attempt_history(
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_uid uuid := auth.uid(); v_result jsonb;
begin
  if v_uid is null then raise exception 'Bạn cần đăng nhập.'; end if;
  if not exists (
    select 1 from public.profiles p
    where p.id=v_uid and p.status='active'
  ) then raise exception 'Tài khoản không hoạt động.'; end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.started_at desc),'[]'::jsonb)
  into v_result
  from (
    select a.id as attempt_id,a.exam_version_id,ev.title,ev.version_no,
      a.status,a.score,a.max_score,a.elapsed_seconds,
      a.started_at,a.finished_at,a.submitted_at
    from public.attempts a
    join public.exam_versions ev on ev.id=a.exam_version_id
    where a.user_id=v_uid
    order by a.started_at desc
    limit greatest(1,least(coalesce(p_limit,50),100))
    offset greatest(coalesce(p_offset,0),0)
  ) x;
  return v_result;
end;
$function$;

revoke all on function public.admin_get_exam_version(uuid) from public,anon;
revoke all on function public.get_my_attempt_state(uuid) from public,anon;
revoke all on function public.get_my_attempt_history(integer,integer) from public,anon;
grant execute on function public.admin_get_exam_version(uuid) to authenticated;
grant execute on function public.get_my_attempt_state(uuid) to authenticated;
grant execute on function public.get_my_attempt_history(integer,integer) to authenticated;
