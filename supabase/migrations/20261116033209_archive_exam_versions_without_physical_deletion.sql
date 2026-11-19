-- Replace the legacy physical-delete RPC with an archive-only operation.
-- Preserve attempts, question mappings, and exam-version rows for audit/history.
-- Deliberately do not GRANT or REVOKE EXECUTE: CREATE OR REPLACE preserves each
-- environment's existing ACL. Production's separate authenticated EXECUTE revocation
-- (20261116033119) therefore remains in force.

begin;

create or replace function public.admin_delete_exam_version(p_exam_version_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_exam_id uuid;
  v_status text;
  v_archived_at timestamptz;
  v_attempt_count integer;
  v_question_count integer;
  v_new_archived_at timestamptz;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được ẩn phiên bản đề thi.';
  end if;

  select exam_id, status, archived_at
    into v_exam_id, v_status, v_archived_at
    from public.exam_versions
   where id = p_exam_version_id
   for update;

  if not found then
    raise exception 'Không tìm thấy phiên bản đề thi.';
  end if;

  if v_archived_at is not null then
    raise exception 'Phiên bản này đã được ẩn trước đó.';
  end if;

  select count(*)::integer
    into v_attempt_count
    from public.attempts
   where exam_version_id = p_exam_version_id;

  select count(*)::integer
    into v_question_count
    from public.exam_version_questions
   where exam_version_id = p_exam_version_id;

  -- The trigger permits only this metadata-only change on published versions.
  perform set_config('app.allow_exam_version_delete', 'on', true);

  update public.exam_versions
     set archived_at = clock_timestamp()
   where id = p_exam_version_id
   returning archived_at into v_new_archived_at;

  -- Audit is part of the same transaction: if it fails, the archive rolls back.
  insert into public.audit_logs (
    actor_id, action, target_type, target_id, details
  ) values (
    auth.uid(),
    'exam_version.archive',
    'exam_version',
    p_exam_version_id::text,
    jsonb_build_object(
      'exam_id', v_exam_id,
      'exam_version_id', p_exam_version_id,
      'status', v_status,
      'attempt_count', v_attempt_count,
      'question_mapping_count', v_question_count,
      'archived_at', v_new_archived_at
    )
  );

  return jsonb_build_object(
    'success', true,
    'archived', true,
    'deleted', false,
    'exam_id', v_exam_id,
    'exam_version_id', p_exam_version_id,
    'attempt_count', v_attempt_count,
    'question_count', v_question_count,
    'message', 'Đã ẩn phiên bản khỏi danh sách đề thi; dữ liệu và lịch sử được giữ nguyên.'
  );
end;
$function$;

commit;
