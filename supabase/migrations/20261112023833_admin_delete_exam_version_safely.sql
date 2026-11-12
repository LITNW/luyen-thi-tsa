-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: d84f69941bbea4a004a677a931219fa2

-- Allow administrators to remove an exam version only through the guarded RPC.
CREATE OR REPLACE FUNCTION public.protect_exam_version()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF current_setting('app.allow_exam_version_delete', true) IS DISTINCT FROM 'on' THEN
      RAISE EXCEPTION 'Chỉ được xóa phiên bản đề qua thao tác quản trị có kiểm tra.';
    END IF;
    IF EXISTS (SELECT 1 FROM public.attempts a WHERE a.exam_version_id = OLD.id) THEN
      RAISE EXCEPTION 'Không thể xóa phiên bản đã có lượt làm bài; cần giữ lịch sử kết quả.';
    END IF;
    RETURN OLD;
  END IF;

  IF OLD.status <> 'draft' THEN
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

CREATE OR REPLACE FUNCTION public.protect_exam_version_questions()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
DECLARE
  v_status text;
  v_exam_id uuid;
  v_scope text;
  v_owner_exam_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    SELECT status INTO v_status
      FROM public.exam_versions
     WHERE id = OLD.exam_version_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Không tìm thấy exam_version.';
    END IF;
    IF current_setting('app.allow_exam_version_delete', true) = 'on' THEN
      RETURN OLD;
    END IF;
    IF v_status <> 'draft' THEN
      RAISE EXCEPTION 'Không được thay đổi danh sách câu hỏi của đề đã xuất bản.';
    END IF;
    RETURN OLD;
  END IF;

  SELECT status, exam_id INTO v_status, v_exam_id
    FROM public.exam_versions WHERE id = NEW.exam_version_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Không tìm thấy exam_version.'; END IF;
  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Không được thay đổi danh sách câu hỏi của đề đã xuất bản.';
  END IF;
  IF NEW.exam_id IS DISTINCT FROM v_exam_id THEN
    RAISE EXCEPTION 'exam_id không khớp với exam_version.';
  END IF;
  SELECT scope, owner_exam_id INTO v_scope, v_owner_exam_id
    FROM public.questions WHERE id = NEW.question_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Không tìm thấy câu hỏi.'; END IF;
  IF v_scope = 'exam' AND v_owner_exam_id IS DISTINCT FROM v_exam_id THEN
    RAISE EXCEPTION 'Câu hỏi riêng của đề khác không được sử dụng ở đề này.';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_delete_exam_version(p_exam_version_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_exam_id uuid;
  v_status text;
  v_attempt_count integer;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Admin mới được xóa phiên bản đề thi.';
  END IF;
  SELECT exam_id, status INTO v_exam_id, v_status
    FROM public.exam_versions
   WHERE id = p_exam_version_id
   FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Không tìm thấy phiên bản đề thi.'; END IF;

  SELECT count(*) INTO v_attempt_count
    FROM public.attempts WHERE exam_version_id = p_exam_version_id;
  IF v_attempt_count > 0 THEN
    RAISE EXCEPTION 'Không thể xóa: phiên bản này đã có % lượt làm bài. Hệ thống giữ lại để bảo toàn lịch sử và kết quả học sinh.', v_attempt_count;
  END IF;

  PERFORM set_config('app.allow_exam_version_delete', 'on', true);
  DELETE FROM public.exam_version_questions WHERE exam_version_id = p_exam_version_id;
  DELETE FROM public.exam_versions WHERE id = p_exam_version_id;

  RETURN jsonb_build_object(
    'success', true,
    'exam_id', v_exam_id,
    'exam_version_id', p_exam_version_id,
    'deleted_status', v_status
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_delete_exam_version(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_exam_version(uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
