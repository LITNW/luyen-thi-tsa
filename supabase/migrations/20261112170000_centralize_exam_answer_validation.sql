-- Centralized answer-key validation for all authoring and publication paths.
-- This migration changes RPC definitions only; it does not rewrite existing exam data.

CREATE OR REPLACE FUNCTION public.validate_question_answer_key(
  p_question_type text,
  p_content jsonb,
  p_answer_key jsonb
)
RETURNS void
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $function$
DECLARE
  v_option_count integer;
  v_value jsonb;
  v_entry record;
  v_number numeric;
  v_integer integer;
  v_seen integer[] := ARRAY[]::integer[];
  v_slot_keys integer[];
  v_answer_slots integer[] := ARRAY[]::integer[];
  v_answer_values integer[] := ARRAY[]::integer[];
BEGIN
  IF p_question_type IS NULL OR p_question_type NOT IN ('mc','ms','tf','num','dnd') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Loại câu hỏi không được hỗ trợ.';
  END IF;

  IF p_content IS NULL
     OR jsonb_typeof(p_content) <> 'object'
     OR jsonb_typeof(p_content->'q') <> 'string'
     OR nullif(btrim(p_content->>'q'),'') IS NULL
     OR jsonb_typeof(p_content->'o') <> 'array' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Nội dung câu hỏi phải có đề bài và mảng phương án.';
  END IF;

  IF p_answer_key IS NULL OR p_answer_key = 'null'::jsonb THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Đáp án không được để trống.';
  END IF;

  v_option_count := jsonb_array_length(p_content->'o');

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_content->'o') AS item(value)
    WHERE jsonb_typeof(item.value) <> 'string'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Mỗi phương án phải là chuỗi văn bản.';
  END IF;

  CASE p_question_type
    WHEN 'mc' THEN
      IF v_option_count < 2 OR jsonb_typeof(p_answer_key) <> 'number' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Đáp án MC phải là chỉ số của một trong ít nhất hai phương án.';
      END IF;
      v_number := (p_answer_key #>> '{}')::numeric;
      IF v_number <> trunc(v_number) OR v_number < 0 OR v_number >= v_option_count THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Chỉ số đáp án MC không hợp lệ.';
      END IF;

    WHEN 'ms' THEN
      IF v_option_count < 2 OR jsonb_typeof(p_answer_key) <> 'array' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Đáp án MS phải là mảng chỉ số phương án.';
      END IF;
      IF jsonb_array_length(p_answer_key) = 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Đáp án MS không được để trống.';
      END IF;
      FOR v_value IN SELECT value FROM jsonb_array_elements(p_answer_key)
      LOOP
        IF jsonb_typeof(v_value) <> 'number' THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Mỗi đáp án MS phải là chỉ số dạng số.';
        END IF;
        v_number := (v_value #>> '{}')::numeric;
        IF v_number <> trunc(v_number) OR v_number < 0 OR v_number >= v_option_count THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Chỉ số đáp án MS nằm ngoài phạm vi phương án.';
        END IF;
        v_integer := v_number::integer;
        IF v_integer = ANY(v_seen) THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Đáp án MS không được chứa chỉ số trùng lặp.';
        END IF;
        v_seen := array_append(v_seen, v_integer);
      END LOOP;

    WHEN 'tf' THEN
      IF v_option_count < 2 OR v_option_count > 4 OR jsonb_typeof(p_answer_key) <> 'array' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Đáp án TF phải là mảng ứng với từ 2 đến 4 ý.';
      END IF;
      IF jsonb_array_length(p_answer_key) <> v_option_count THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Số đáp án TF phải khớp số lượng ý.';
      END IF;
      IF EXISTS (
        SELECT 1 FROM jsonb_array_elements(p_answer_key) AS item(value)
        WHERE jsonb_typeof(item.value) <> 'boolean'
      ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Mỗi đáp án TF phải là giá trị đúng/sai.';
      END IF;

    WHEN 'num' THEN
      IF jsonb_typeof(p_answer_key) <> 'number' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Đáp án NUM phải là số.';
      END IF;

    WHEN 'dnd' THEN
      IF v_option_count < 1 OR jsonb_typeof(p_answer_key) <> 'object' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Đáp án DND phải là đối tượng ghép nối.';
      END IF;

      -- Reject malformed/overflowing slot markers before casting them to integer.
      IF NOT EXISTS (
        SELECT 1
        FROM regexp_matches(p_content->>'q', '\[([0-9]+)\]', 'g') AS matches(match_parts)
      ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Câu DND phải có ít nhất một vị trí ghép [1], [2], ...';
      END IF;
      IF EXISTS (
        SELECT 1
        FROM regexp_matches(p_content->>'q', '\[([0-9]+)\]', 'g') AS matches(match_parts)
        WHERE (match_parts)[1]::numeric < 1
           OR (match_parts)[1]::numeric > 2147483647
      ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Vị trí ghép DND phải là số nguyên dương hợp lệ.';
      END IF;

      SELECT coalesce(array_agg(slot ORDER BY slot), ARRAY[]::integer[])
        INTO v_slot_keys
      FROM (
        SELECT DISTINCT (match_parts)[1]::integer AS slot
        FROM regexp_matches(p_content->>'q', '\[([0-9]+)\]', 'g') AS matches(match_parts)
      ) AS slots;

      FOR v_entry IN SELECT key, value FROM jsonb_each(p_answer_key)
      LOOP
        IF v_entry.key !~ '^[1-9][0-9]*$' THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Khóa vị trí DND phải là số nguyên dương.';
        END IF;
        v_number := v_entry.key::numeric;
        IF v_number > 2147483647 THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Khóa vị trí DND vượt giới hạn.';
        END IF;
        IF jsonb_typeof(v_entry.value) <> 'number' THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Giá trị ghép DND phải là chỉ số phương án dạng số.';
        END IF;
        v_number := (v_entry.value #>> '{}')::numeric;
        IF v_number <> trunc(v_number) OR v_number < 1 OR v_number > v_option_count THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Chỉ số phương án DND nằm ngoài phạm vi.';
        END IF;
        v_answer_slots := array_append(v_answer_slots, v_entry.key::integer);
        v_answer_values := array_append(v_answer_values, v_number::integer);
      END LOOP;

      SELECT coalesce(array_agg(value ORDER BY value), ARRAY[]::integer[])
        INTO v_answer_slots
      FROM unnest(v_answer_slots) AS slots(value);

      IF v_answer_slots IS DISTINCT FROM v_slot_keys THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Đáp án DND phải khớp chính xác các vị trí cần ghép.';
      END IF;
      IF cardinality(v_answer_values) <> (
        SELECT count(DISTINCT value) FROM unnest(v_answer_values) AS choices(value)
      ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Một phương án DND không được ghép cho nhiều vị trí.';
      END IF;
  END CASE;
END;
$function$;

REVOKE ALL ON FUNCTION public.validate_question_answer_key(text,jsonb,jsonb) FROM PUBLIC, anon, authenticated;

-- Replace the complete authoring RPC instead of editing its generated source text.
-- This retains the original scope, ownership, public-content, and versioning rules.
CREATE OR REPLACE FUNCTION public.admin_save_question(
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
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_question_id uuid;
  v_question_version_id uuid;
  v_existing public.questions%rowtype;
  v_version_no integer;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Admin mới được tạo hoặc cập nhật câu hỏi.';
  END IF;

  IF p_scope IS NULL OR p_scope NOT IN ('bank','exam')
     OR (p_scope = 'bank' AND p_owner_exam_id IS NOT NULL)
     OR (p_scope = 'exam' AND p_owner_exam_id IS NULL) THEN
    RAISE EXCEPTION 'Phạm vi câu hỏi không hợp lệ.';
  END IF;

  IF p_scope = 'exam' AND NOT EXISTS (
    SELECT 1 FROM public.exams e WHERE e.id = p_owner_exam_id
  ) THEN
    RAISE EXCEPTION 'Đề sở hữu câu hỏi không tồn tại.';
  END IF;

  IF p_content IS NOT NULL
     AND jsonb_typeof(p_content) = 'object'
     AND p_content ?| ARRAY['a','answer','answer_key','e','explanation','fm'] THEN
    RAISE EXCEPTION 'Không được đưa đáp án, lời giải hoặc metadata đáp án vào nội dung công khai.';
  END IF;

  PERFORM public.validate_question_answer_key(p_question_type,p_content,p_answer_key);

  IF p_question_id IS NULL THEN
    INSERT INTO public.questions(scope,owner_exam_id,created_by)
    VALUES (p_scope,p_owner_exam_id,auth.uid())
    RETURNING id INTO v_question_id;
  ELSE
    SELECT * INTO v_existing
    FROM public.questions q
    WHERE q.id = p_question_id
    FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Không tìm thấy câu hỏi cần cập nhật.';
    END IF;
    IF v_existing.scope <> p_scope
       OR v_existing.owner_exam_id IS DISTINCT FROM p_owner_exam_id THEN
      RAISE EXCEPTION 'Không được thay đổi phạm vi hoặc đề sở hữu của câu hỏi.';
    END IF;
    v_question_id := p_question_id;
  END IF;

  SELECT coalesce(max(qv.version_no),0)+1
    INTO v_version_no
  FROM public.question_versions qv
  WHERE qv.question_id = v_question_id;

  INSERT INTO public.question_versions(
    question_id,version_no,question_type,content,created_by
  ) VALUES (
    v_question_id,v_version_no,p_question_type,p_content,auth.uid()
  ) RETURNING id INTO v_question_version_id;

  INSERT INTO public.question_answer_keys(
    question_version_id,answer_key,explanation,grading_config,source_metadata
  ) VALUES (
    v_question_version_id,p_answer_key,coalesce(p_explanation,''),
    coalesce(p_grading_config,'{}'::jsonb),coalesce(p_source_metadata,'{}'::jsonb)
  );

  RETURN v_question_version_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_set_question_answer_key(
  p_question_version_id uuid,
  p_answer_key jsonb,
  p_explanation text DEFAULT '',
  p_grading_config jsonb DEFAULT '{}'::jsonb,
  p_source_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_type text;
  v_content jsonb;
  v_existing public.question_answer_keys%rowtype;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Admin mới được thiết lập đáp án.';
  END IF;

  SELECT qv.question_type, qv.content
    INTO v_type, v_content
  FROM public.question_versions qv
  WHERE qv.id = p_question_version_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Không tìm thấy phiên bản câu hỏi.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.exam_version_questions evq
    JOIN public.exam_versions ev ON ev.id = evq.exam_version_id
    WHERE evq.question_version_id = p_question_version_id
      AND ev.status = 'published'
  ) THEN
    RAISE EXCEPTION 'Không thể thay đổi đáp án của câu hỏi đã được xuất bản.';
  END IF;

  PERFORM public.validate_question_answer_key(v_type,v_content,p_answer_key);

  SELECT * INTO v_existing
  FROM public.question_answer_keys ak
  WHERE ak.question_version_id = p_question_version_id;

  IF FOUND THEN
    IF v_existing.answer_key = p_answer_key
       AND v_existing.explanation = coalesce(p_explanation,'')
       AND v_existing.grading_config = coalesce(p_grading_config,'{}'::jsonb)
       AND v_existing.source_metadata = coalesce(p_source_metadata,'{}'::jsonb) THEN
      RETURN false;
    END IF;
    RAISE EXCEPTION 'Đáp án của phiên bản câu hỏi đã tồn tại và bất biến. Hãy tạo phiên bản câu hỏi mới.';
  END IF;

  INSERT INTO public.question_answer_keys(
    question_version_id,answer_key,explanation,grading_config,source_metadata
  ) VALUES (
    p_question_version_id,p_answer_key,coalesce(p_explanation,''),
    coalesce(p_grading_config,'{}'::jsonb),coalesce(p_source_metadata,'{}'::jsonb)
  );

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_set_question_answer_key(uuid,jsonb,text,jsonb,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_question_answer_key(uuid,jsonb,text,jsonb,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_publish_exam_version(p_exam_version_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_exam public.exam_versions%rowtype;
  v_question record;
  v_total integer := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Admin mới được xuất bản đề thi.';
  END IF;

  SELECT * INTO v_exam
  FROM public.exam_versions ev
  WHERE ev.id = p_exam_version_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Không tìm thấy phiên bản đề thi.';
  END IF;
  IF v_exam.status <> 'draft' THEN
    RAISE EXCEPTION 'Chỉ phiên bản nháp mới có thể xuất bản.';
  END IF;

  FOR v_question IN
    SELECT evq.position, qv.question_type, qv.content, ak.answer_key
    FROM public.exam_version_questions evq
    JOIN public.question_versions qv ON qv.id = evq.question_version_id
    LEFT JOIN public.question_answer_keys ak ON ak.question_version_id = qv.id
    WHERE evq.exam_version_id = p_exam_version_id
    ORDER BY evq.position
  LOOP
    v_total := v_total + 1;
    IF v_question.answer_key IS NULL THEN
      RAISE EXCEPTION 'Câu % chưa có đáp án.', v_question.position;
    END IF;
    BEGIN
      PERFORM public.validate_question_answer_key(
        v_question.question_type,v_question.content,v_question.answer_key
      );
    EXCEPTION WHEN SQLSTATE '22023' THEN
      RAISE EXCEPTION 'Câu % không hợp lệ: %', v_question.position, SQLERRM;
    END;
  END LOOP;

  IF v_total = 0 THEN
    RAISE EXCEPTION 'Đề thi chưa có câu hỏi.';
  END IF;

  UPDATE public.exam_versions
  SET status = 'published',
      published_by = auth.uid(),
      published_at = pg_catalog.now()
  WHERE id = p_exam_version_id;

  RETURN jsonb_build_object(
    'success',true,
    'exam_version_id',p_exam_version_id,
    'question_count',v_total,
    'published_at',pg_catalog.now()
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_publish_exam_version(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_publish_exam_version(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
