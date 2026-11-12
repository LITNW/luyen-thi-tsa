-- TSA exam room: server-authoritative deadline, auto-submit grace and idempotent offline time sync.
-- This migration is intentionally committed but not applied to the live project until review/approval.

CREATE TABLE IF NOT EXISTS public.attempt_question_time_events (
    event_id uuid PRIMARY KEY,
    attempt_id uuid NOT NULL,
    exam_version_id uuid NOT NULL,
    exam_version_question_id uuid NOT NULL,
    seconds_spent integer NOT NULL CHECK (seconds_spent BETWEEN 0 AND 300),
    visit_increment integer NOT NULL CHECK (visit_increment IN (0, 1)),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT attempt_question_time_events_attempt_fk
      FOREIGN KEY (attempt_id, exam_version_id)
      REFERENCES public.attempts (id, exam_version_id) ON DELETE CASCADE,
    CONSTRAINT attempt_question_time_events_question_fk
      FOREIGN KEY (exam_version_question_id, exam_version_id)
      REFERENCES public.exam_version_questions (id, exam_version_id) ON DELETE CASCADE
);

ALTER TABLE public.attempt_question_time_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.attempt_question_time_events FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.record_attempt_question_time_v2(
    p_attempt_id uuid,
    p_exam_version_question_id uuid,
    p_seconds integer,
    p_visit_increment integer,
    p_event_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_attempt record;
    v_inserted uuid;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_event_id IS NULL
       OR p_seconds IS NULL OR p_seconds < 0 OR p_seconds > 300
       OR p_visit_increment IS NULL OR p_visit_increment NOT IN (0, 1) THEN
        RAISE EXCEPTION 'Giá trị thời gian không hợp lệ.';
    END IF;

    SELECT a.user_id, a.exam_version_id, a.status, a.started_at, ev.duration_minutes
      INTO v_attempt
      FROM public.attempts a
      JOIN public.exam_versions ev ON ev.id = a.exam_version_id
     WHERE a.id = p_attempt_id
     FOR UPDATE OF a;

    IF NOT FOUND
       OR v_attempt.user_id IS DISTINCT FROM v_uid
       OR v_attempt.status <> 'in_progress' THEN
        RAISE EXCEPTION 'Không có quyền ghi thời gian cho lần thi này.';
    END IF;

    IF clock_timestamp() >=
       v_attempt.started_at + make_interval(mins => v_attempt.duration_minutes) THEN
        RAISE EXCEPTION 'Đã hết thời gian làm bài.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM public.exam_version_questions evq
         WHERE evq.id = p_exam_version_question_id
           AND evq.exam_version_id = v_attempt.exam_version_id
    ) THEN
        RAISE EXCEPTION 'Câu hỏi không thuộc lần thi này.';
    END IF;

    INSERT INTO public.attempt_question_time_events (
        event_id, attempt_id, exam_version_id, exam_version_question_id,
        seconds_spent, visit_increment
    )
    VALUES (
        p_event_id, p_attempt_id, v_attempt.exam_version_id,
        p_exam_version_question_id, p_seconds, p_visit_increment
    )
    ON CONFLICT (event_id) DO NOTHING
    RETURNING event_id INTO v_inserted;

    -- Replayed requests are harmless: aggregate time only once.
    IF v_inserted IS NULL THEN
        RETURN;
    END IF;

    INSERT INTO public.attempt_question_times (
        attempt_id, exam_version_id, exam_version_question_id,
        seconds_spent, visit_count
    )
    VALUES (
        p_attempt_id, v_attempt.exam_version_id, p_exam_version_question_id,
        p_seconds, p_visit_increment
    )
    ON CONFLICT (attempt_id, exam_version_question_id)
    DO UPDATE SET
        seconds_spent = LEAST(
            public.attempt_question_times.seconds_spent + EXCLUDED.seconds_spent,
            v_attempt.duration_minutes * 60
        ),
        visit_count = public.attempt_question_times.visit_count + EXCLUDED.visit_count,
        updated_at = clock_timestamp();

    UPDATE public.attempts
       SET last_activity_at = clock_timestamp()
     WHERE id = p_attempt_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.record_attempt_question_time_v2(uuid, uuid, integer, integer, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_attempt_question_time_v2(uuid, uuid, integer, integer, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_attempt_state(p_attempt_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_attempt public.attempts%rowtype;
    v_duration integer;
    v_now timestamptz;
    v_deadline timestamptz;
    v_result jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Bạn cần đăng nhập.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.profiles p
         WHERE p.id = v_uid AND p.status = 'active'
    ) THEN
        RAISE EXCEPTION 'Tài khoản không hoạt động.';
    END IF;

    SELECT * INTO v_attempt
      FROM public.attempts a
     WHERE a.id = p_attempt_id AND a.user_id = v_uid
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy lần làm bài của tài khoản này.';
    END IF;

    SELECT ev.duration_minutes INTO v_duration
      FROM public.exam_versions ev
     WHERE ev.id = v_attempt.exam_version_id;

    v_deadline := v_attempt.started_at + make_interval(mins => v_duration);
    v_now := clock_timestamp();

    -- Server finalizes an expired attempt after the agreed 10-second lock countdown.
    -- This runs on the next authenticated state request if the browser was offline.
    IF v_attempt.status = 'in_progress'
       AND v_now >= v_deadline + interval '10 seconds' THEN
        PERFORM public.submit_exam_attempt(p_attempt_id);
        SELECT * INTO v_attempt
          FROM public.attempts a
         WHERE a.id = p_attempt_id AND a.user_id = v_uid
         FOR UPDATE;
        v_now := clock_timestamp();
    END IF;

    SELECT jsonb_build_object(
        'attempt_id', v_attempt.id,
        'exam_version_id', v_attempt.exam_version_id,
        'status', v_attempt.status,
        'started_at', v_attempt.started_at,
        'finished_at', v_attempt.finished_at,
        'duration_minutes', v_duration,
        'deadline_at', v_deadline,
        'auto_submit_at', v_deadline + interval '10 seconds',
        'server_now', v_now,
        'remaining_seconds', GREATEST(0, CEIL(EXTRACT(EPOCH FROM (v_deadline - v_now)))::integer),
        'auto_submit_remaining_seconds', GREATEST(0, CEIL(EXTRACT(EPOCH FROM (v_deadline + interval '10 seconds' - v_now)))::integer),
        'elapsed_seconds', v_attempt.elapsed_seconds,
        'answers', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'exam_version_question_id', aa.exam_version_question_id,
                'answer', aa.answer
            ))
              FROM public.attempt_answers aa
             WHERE aa.attempt_id = v_attempt.id
        ), '[]'::jsonb),
        'question_times', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'exam_version_question_id', t.exam_version_question_id,
                'seconds_spent', t.seconds_spent,
                'visit_count', t.visit_count
            ))
              FROM public.attempt_question_times t
             WHERE t.attempt_id = v_attempt.id
        ), '[]'::jsonb),
        'result_details', CASE WHEN v_attempt.status = 'submitted' THEN v_attempt.result_details ELSE NULL END,
        'score', CASE WHEN v_attempt.status = 'submitted' THEN v_attempt.score ELSE NULL END,
        'max_score', CASE WHEN v_attempt.status = 'submitted' THEN v_attempt.max_score ELSE NULL END
    ) INTO v_result;

    RETURN v_result;
END;
$function$;

NOTIFY pgrst, 'reload schema';
