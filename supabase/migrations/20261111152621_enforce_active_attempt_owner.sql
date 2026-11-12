-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: undefined

-- Migration 014: enforce active account ownership at the attempt-table trigger boundary.
-- This also blocks a suspended student from continuing an already-open attempt.

create or replace function public.guard_attempt_child()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_attempt_id uuid;
  v_status text;
  v_user_id uuid;
begin
  if tg_op = 'DELETE' then
    v_attempt_id := old.attempt_id;
  else
    v_attempt_id := new.attempt_id;
  end if;

  if tg_op = 'UPDATE' then
    if new.attempt_id is distinct from old.attempt_id
       or new.exam_version_id is distinct from old.exam_version_id
       or new.exam_version_question_id is distinct from old.exam_version_question_id then
      raise exception 'Không được chuyển câu trả lời sang lần thi hoặc câu hỏi khác.';
    end if;
  end if;

  select a.user_id,a.status
  into v_user_id,v_status
  from public.attempts a
  where a.id=v_attempt_id;

  if not found
     or v_status<>'in_progress'
     or auth.uid() is null
     or v_user_id is distinct from auth.uid()
     or not exists (
       select 1 from public.profiles p
       where p.id=auth.uid() and p.status='active'
     ) then
    raise exception 'Chỉ chủ tài khoản đang hoạt động mới được sửa dữ liệu của lần làm bài đang diễn ra.';
  end if;

  if tg_op='DELETE' then return old; end if;
  return new;
end;
$function$;

create or replace function public.guard_attempt_record()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op='DELETE' then
    raise exception 'Không được xóa lịch sử làm bài.';
  end if;

  if old.status<>'in_progress' then
    raise exception 'Lần làm bài đã kết thúc và không thể chỉnh sửa.';
  end if;

  if new.id is distinct from old.id
     or new.user_id is distinct from old.user_id
     or new.exam_id is distinct from old.exam_id
     or new.exam_version_id is distinct from old.exam_version_id
     or new.started_at is distinct from old.started_at
     or new.max_score is distinct from old.max_score then
    raise exception 'Không được thay đổi định danh hoặc chủ sở hữu lần làm bài.';
  end if;

  if auth.uid() is null
     or old.user_id is distinct from auth.uid()
     or not exists (
       select 1 from public.profiles p
       where p.id=auth.uid() and p.status='active'
     ) then
    raise exception 'Chỉ chủ tài khoản đang hoạt động mới được cập nhật lần làm bài.';
  end if;

  return new;
end;
$function$;

revoke all on function public.guard_attempt_child() from public,anon,authenticated;
revoke all on function public.guard_attempt_record() from public,anon,authenticated;
