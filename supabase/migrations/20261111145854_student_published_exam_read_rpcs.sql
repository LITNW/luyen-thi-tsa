-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: a8606fa58f9b2652e5e2226846a00afd

begin;

create or replace function public.list_published_exams()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Bạn cần đăng nhập để xem danh sách đề thi.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = v_uid and p.status = 'active'
  ) then
    raise exception 'Tài khoản không hoạt động.';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ev.id,
        'exam_id', ev.exam_id,
        'version_no', ev.version_no,
        'title', ev.title,
        'description', ev.description,
        'duration_minutes', ev.duration_minutes,
        'published_at', ev.published_at,
        'question_count', (
          select count(*) from public.exam_version_questions evq
          where evq.exam_version_id = ev.id
        )
      )
      order by ev.published_at desc nulls last, ev.created_at desc
    ),
    '[]'::jsonb
  )
  into v_result
  from public.exam_versions ev
  where ev.status = 'published';

  return v_result;
end;
$function$;

create or replace function public.get_published_exam(p_exam_version_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_exam jsonb;
begin
  if v_uid is null then
    raise exception 'Bạn cần đăng nhập để xem đề thi.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = v_uid and p.status = 'active'
  ) then
    raise exception 'Tài khoản không hoạt động.';
  end if;

  select jsonb_build_object(
    'id', ev.id,
    'exam_id', ev.exam_id,
    'version_no', ev.version_no,
    'title', ev.title,
    'description', ev.description,
    'duration_minutes', ev.duration_minutes,
    'questions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', evq.id,
          'position', evq.position,
          'points', evq.points,
          'type', qv.question_type,
          'content', qv.content
        )
        order by evq.position
      )
      from public.exam_version_questions evq
      join public.question_versions qv
        on qv.id = evq.question_version_id
      where evq.exam_version_id = ev.id
    ), '[]'::jsonb)
  )
  into v_exam
  from public.exam_versions ev
  where ev.id = p_exam_version_id
    and ev.status = 'published';

  if v_exam is null then
    raise exception 'Không tìm thấy đề đã xuất bản.';
  end if;

  return v_exam;
end;
$function$;

revoke all on function public.list_published_exams() from public, anon;
revoke all on function public.get_published_exam(uuid) from public, anon;
grant execute on function public.list_published_exams() to authenticated;
grant execute on function public.get_published_exam(uuid) to authenticated;

commit;
