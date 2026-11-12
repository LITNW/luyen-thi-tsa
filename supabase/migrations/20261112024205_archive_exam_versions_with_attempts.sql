-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: undefined
-- Preserve historical attempts while allowing admins to remove published exams from circulation.
ALTER TABLE public.exam_versions
  ADD COLUMN IF NOT EXISTS archived_at timestamptz;

CREATE INDEX IF NOT EXISTS exam_versions_active_published_idx
  ON public.exam_versions (published_at DESC)
  WHERE status = 'published' AND archived_at IS NULL;

CREATE OR REPLACE FUNCTION public.protect_exam_version()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF current_setting('app.allow_exam_version_delete', true) IS DISTINCT FROM 'on' THEN
      RAISE EXCEPTION 'Chỉ được xóa phiên bản đề qua thao tác quản trị có kiểm tra.';
    END IF;
    IF EXISTS (SELECT 1 FROM public.attempts a WHERE a.exam_version_id = OLD.id) THEN
      RAISE EXCEPTION 'Không thể xóa phiên bản đã có lượt làm bài; cần giữ lại lịch sử kết quả.';
    END IF;
    RETURN OLD;
  END IF;

  IF OLD.status <> 'draft' THEN
    IF current_setting('app.allow_exam_version_delete', true) = 'on'
       AND OLD.status = 'published'
       AND NEW.archived_at IS DISTINCT FROM OLD.archived_at
       AND (to_jsonb(NEW) - 'archived_at') = (to_jsonb(OLD) - 'archived_at') THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Phiên bản đã xuất bản không thể chỉnh sửa. Hãy tạo phiên bản mới.';
  END IF;

  IF NEW.exam_id IS DISTINCT FROM OLD.exam_id
     OR NEW.version_no IS DISTINCT FROM OLD.version_no
     OR NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Không được thay đổi định danh hoặc số phiên bản đề thi.';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_delete_exam_version(p_exam_version_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_exam_id uuid; v_status text; v_attempt_count integer; v_archived_at timestamptz;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Admin mới được xóa phiên bản đề thi.';
  END IF;
  SELECT exam_id, status, archived_at INTO v_exam_id, v_status, v_archived_at
    FROM public.exam_versions WHERE id = p_exam_version_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Không tìm thấy phiên bản đề thi.'; END IF;
  IF v_archived_at IS NOT NULL THEN
    RAISE EXCEPTION 'Phiên bản này đã được ẩn trước đó.';
  END IF;

  SELECT count(*) INTO v_attempt_count
    FROM public.attempts WHERE exam_version_id = p_exam_version_id;

  PERFORM set_config('app.allow_exam_version_delete', 'on', true);
  IF v_attempt_count > 0 THEN
    UPDATE public.exam_versions SET archived_at = clock_timestamp()
     WHERE id = p_exam_version_id;
    RETURN jsonb_build_object(
      'success', true, 'archived', true, 'deleted', false,
      'exam_id', v_exam_id, 'exam_version_id', p_exam_version_id,
      'attempt_count', v_attempt_count,
      'message', 'Đã ẩn phiên bản khỏi danh sách đề thi; lịch sử làm bài được giữ nguyên.'
    );
  END IF;

  DELETE FROM public.exam_version_questions WHERE exam_version_id = p_exam_version_id;
  DELETE FROM public.exam_versions WHERE id = p_exam_version_id;
  RETURN jsonb_build_object(
    'success', true, 'archived', false, 'deleted', true,
    'exam_id', v_exam_id, 'exam_version_id', p_exam_version_id,
    'deleted_status', v_status
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_exam_versions()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Admin mới được xem danh sách quản trị đề thi.';
  END IF;
  SELECT coalesce(jsonb_agg(
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
      'question_count', (SELECT count(*) FROM public.exam_version_questions evq WHERE evq.exam_version_id = ev.id),
      'attempt_count', (SELECT count(*) FROM public.attempts a WHERE a.exam_version_id = ev.id)
    ) ORDER BY ev.created_at DESC
  ), '[]'::jsonb)
  INTO v_result
  FROM public.exam_versions ev
  WHERE ev.archived_at IS NULL;
  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.list_published_exams()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_uid uuid := auth.uid(); v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Bạn cần đăng nhập để xem danh sách đề thi.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_uid AND p.status = 'active') THEN
    RAISE EXCEPTION 'Tài khoản không hoạt động.';
  END IF;
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', ev.id, 'exam_id', ev.exam_id, 'version_no', ev.version_no,
      'title', ev.title, 'description', ev.description,
      'duration_minutes', ev.duration_minutes, 'published_at', ev.published_at,
      'question_count', (SELECT count(*) FROM public.exam_version_questions evq WHERE evq.exam_version_id = ev.id)
    ) ORDER BY ev.published_at DESC NULLS LAST, ev.created_at DESC
  ), '[]'::jsonb)
  INTO v_result
  FROM public.exam_versions ev
  WHERE ev.status = 'published' AND ev.archived_at IS NULL;
  RETURN v_result;
END;
$function$;

-- Prevent new attempts for archived versions; existing attempts can still resume.
DO $migration$
DECLARE v_definition text;
BEGIN
  v_definition := pg_get_functiondef('public.start_exam_attempt(uuid)'::regprocedure);
  IF position('AND archived_at IS NULL' IN v_definition) = 0 THEN
    IF position('AND status = ''published''' IN v_definition) = 0 THEN
      RAISE EXCEPTION 'Không tìm thấy điều kiện published trong start_exam_attempt; dừng migration.';
    END IF;
    v_definition := replace(
      v_definition,
      'AND status = ''published''',
      'AND status = ''published'' AND archived_at IS NULL'
    );
    EXECUTE v_definition;
  END IF;
END;
$migration$;

REVOKE ALL ON FUNCTION public.admin_delete_exam_version(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_exam_version(uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
