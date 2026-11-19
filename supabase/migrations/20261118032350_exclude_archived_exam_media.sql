-- Prevent archived published exam versions from exposing exam payloads or media.
-- Forward-only function replacement; no table data or schema is changed.

begin;

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
        and ev.archived_at is null
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
    and ev.status = 'published'
    and ev.archived_at is null;

  if v_exam is null then
    raise exception 'Không tìm thấy đề đã xuất bản.';
  end if;

  return v_exam;
end;
$function$;

commit;
