-- Smoke test after applying the 17 recovered Production migrations to the pre-005 fixture.
DO $test$
DECLARE
  v_missing text;
BEGIN
  IF to_regclass('public.attempt_question_time_events') IS NULL THEN
    RAISE EXCEPTION 'Migration 018 did not create attempt_question_time_events.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='exam_versions' AND column_name='archived_at'
  ) THEN
    RAISE EXCEPTION 'Migration 020 did not add exam_versions.archived_at.';
  END IF;

  SELECT string_agg(required_name, ', ')
  INTO v_missing
  FROM unnest(ARRAY[
    'bootstrap_first_admin',
    'admin_create_exam',
    'admin_create_exam_version',
    'admin_set_question_answer_key',
    'admin_publish_exam_version',
    'list_published_exams',
    'get_published_exam',
    'admin_update_profile',
    'admin_save_question',
    'admin_save_exam_content',
    'get_my_attempt_state',
    'get_my_attempt_history',
    'record_attempt_question_time_v2',
    'admin_delete_exam_version'
  ]) AS required_name
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname=required_name
  );

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Missing expected RPCs after migration chain: %',v_missing;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='attempts_guard_update' AND NOT tgisinternal)
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='attempt_answers_guard' AND NOT tgisinternal)
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='exam_versions_immutable_after_publish' AND NOT tgisinternal)
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='exam_version_questions_protected' AND NOT tgisinternal) THEN
    RAISE EXCEPTION 'One or more integrity triggers are missing after migration chain.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND policyname='exam_versions_read_published_or_admin')
     OR NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND policyname='questions_admin_select')
     OR NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND policyname='profiles_update_own_or_admin') THEN
    RAISE EXCEPTION 'Expected RLS policies are missing after migration chain.';
  END IF;

  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.attempt_question_time_events'::regclass) THEN
    RAISE EXCEPTION 'RLS is not enabled on attempt_question_time_events.';
  END IF;
END;
$test$;
