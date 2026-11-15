-- PHASE 12 — FUNCTION ACL REMEDIATION DRAFT
-- NOT A MIGRATION. Stored under docs/architecture/drafts/.
-- DO NOT RUN until the ACL snapshot, anonymous-catalogue decision,
-- service-role/default-privilege review, and Staging E2E plan are approved.
--
-- This draft targets the Production baseline of 74 public functions.
-- Staging currently has 72 functions; do not run this file unchanged there.
-- Existing service_role grants are intentionally left unchanged.
--
-- PostgreSQL role ACL cannot encode "authenticated AND profile.role=admin".
-- The 26 admin_* function bodies must enforce is_admin() internally.

BEGIN;

DO $preflight$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prokind = 'f';

  IF v_count <> 74 THEN
    RAISE EXCEPTION
      'Phase 12 ACL draft aborted: expected 74 public functions, found %; refresh inventory first.',
      v_count;
  END IF;

  IF to_regprocedure('public.abandon_exam_attempt(uuid)') IS NULL
     OR to_regprocedure('public.save_exam_atomic(uuid,text,text,integer,jsonb,jsonb,boolean,uuid)') IS NULL
     OR to_regprocedure('public.start_exam_attempt(uuid)') IS NULL
     OR to_regprocedure('public.save_attempt_answer(uuid,uuid,jsonb)') IS NULL
     OR to_regprocedure('public.is_admin()') IS NULL
     OR to_regprocedure('public.list_published_exams_for_education_subject(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Phase 12 ACL draft aborted: expected function identity missing.';
  END IF;
END
$preflight$;

-- Remove inherited PUBLIC and direct client-role EXECUTE rights across the
-- current public function set. Trigger execution itself is not a direct RPC.
-- service_role ACL entries are not touched by this statement.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public
  FROM PUBLIC, anon, authenticated;

-- Authenticated student APIs and attempt lifecycle.
GRANT EXECUTE ON FUNCTION public.abandon_exam_attempt(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_attempt_history(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_attempt_state(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_published_exam(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_attempt_question_time_v2(uuid,uuid,integer,integer,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_attempt_question_time(uuid,uuid,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_attempt_answer(uuid,uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_exam_attempt(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_exam_attempt(uuid) TO authenticated;

-- Admin/authoring RPCs: authenticated is the transport role; is_admin()
-- authorization remains mandatory inside every function body.
GRANT EXECUTE ON FUNCTION public.admin_add_question_to_exam(uuid,uuid,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_exam_version(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_exam(text,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_exam_version(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_exam_version(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_attempts(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_exam_categories() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_exam_versions_with_categories() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_exam_versions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_profiles(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_question_bank(text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_publish_exam_version(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_question_from_exam(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reorder_exam_questions(uuid,uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_replace_question_in_exam(uuid,uuid,uuid,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_exam_category(text,text,uuid,text,uuid,boolean,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_exam_content_with_category(uuid,text,text,integer,jsonb,uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_exam_content_with_education(uuid,text,text,integer,jsonb,uuid,uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_exam_content(uuid,text,text,integer,jsonb,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_question(uuid,text,uuid,text,jsonb,jsonb,text,jsonb,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_exam_category(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_exam_education_subject(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_question_answer_key(uuid,jsonb,text,jsonb,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_exam_version(uuid,text,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_profile(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_question_points(uuid,uuid,numeric) TO authenticated;

-- Authenticated catalogue/read helpers and one-time bootstrap.
-- No anon grant: current function bodies require an active auth.uid().
GRANT EXECUTE ON FUNCTION public.bootstrap_first_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_active_exam_categories() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_active_subjects() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_published_exams_for_education_subject(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_published_exams() TO authenticated;

-- Post-change assertions inside the same transaction.
DO $verify$
DECLARE
  v_anon_count integer;
  v_auth_missing integer;
  v_auth_count integer;
  v_service_count integer;
BEGIN
  SELECT count(*) INTO v_anon_count
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prokind = 'f'
    AND has_function_privilege('anon', p.oid, 'EXECUTE');

  IF v_anon_count <> 0 THEN
    RAISE EXCEPTION 'ACL verification failed: % public functions remain executable by anon.', v_anon_count;
  END IF;

  SELECT count(*) INTO v_auth_missing
  FROM (VALUES
    ('public.abandon_exam_attempt(uuid)'),
    ('public.get_my_attempt_history(integer,integer)'),
    ('public.get_my_attempt_state(uuid)'),
    ('public.get_published_exam(uuid)'),
    ('public.record_attempt_question_time_v2(uuid,uuid,integer,integer,uuid)'),
    ('public.record_attempt_question_time(uuid,uuid,integer,integer)'),
    ('public.save_attempt_answer(uuid,uuid,jsonb)'),
    ('public.start_exam_attempt(uuid)'),
    ('public.submit_exam_attempt(uuid)'),
    ('public.bootstrap_first_admin()'),
    ('public.is_admin()'),
    ('public.list_active_exam_categories()'),
    ('public.list_active_subjects()'),
    ('public.list_published_exams_for_education_subject(uuid)'),
    ('public.list_published_exams()'),
    ('public.admin_add_question_to_exam(uuid,uuid,numeric)'),
    ('public.admin_create_exam_version(uuid)'),
    ('public.admin_create_exam(text,text,integer)'),
    ('public.admin_delete_exam_version(uuid)'),
    ('public.admin_get_exam_version(uuid)'),
    ('public.admin_list_attempts(integer,integer)'),
    ('public.admin_list_exam_categories()'),
    ('public.admin_list_exam_versions_with_categories()'),
    ('public.admin_list_exam_versions()'),
    ('public.admin_list_profiles(integer,integer)'),
    ('public.admin_list_question_bank(text,integer,integer)'),
    ('public.admin_publish_exam_version(uuid)'),
    ('public.admin_remove_question_from_exam(uuid,uuid)'),
    ('public.admin_reorder_exam_questions(uuid,uuid[])'),
    ('public.admin_replace_question_in_exam(uuid,uuid,uuid,numeric)'),
    ('public.admin_save_exam_category(text,text,uuid,text,uuid,boolean,integer)'),
    ('public.admin_save_exam_content_with_category(uuid,text,text,integer,jsonb,uuid,boolean)'),
    ('public.admin_save_exam_content_with_education(uuid,text,text,integer,jsonb,uuid,uuid,boolean)'),
    ('public.admin_save_exam_content(uuid,text,text,integer,jsonb,boolean)'),
    ('public.admin_save_question(uuid,text,uuid,text,jsonb,jsonb,text,jsonb,jsonb)'),
    ('public.admin_set_exam_category(uuid,uuid)'),
    ('public.admin_set_exam_education_subject(uuid,uuid)'),
    ('public.admin_set_question_answer_key(uuid,jsonb,text,jsonb,jsonb)'),
    ('public.admin_update_exam_version(uuid,text,text,integer)'),
    ('public.admin_update_profile(uuid,text,text,text)'),
    ('public.admin_update_question_points(uuid,uuid,numeric)')
  ) AS expected(signature)
  WHERE to_regprocedure(expected.signature) IS NULL
     OR NOT has_function_privilege('authenticated', to_regprocedure(expected.signature), 'EXECUTE');

  IF v_auth_missing <> 0 THEN
    RAISE EXCEPTION 'ACL verification failed: % expected authenticated grants are missing.', v_auth_missing;
  END IF;

  SELECT count(*) INTO v_auth_count
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prokind = 'f'
    AND has_function_privilege('authenticated', p.oid, 'EXECUTE');

  IF v_auth_count <> 41 THEN
    RAISE EXCEPTION 'ACL verification failed: expected exactly 41 authenticated-callable functions, found %.', v_auth_count;
  END IF;

  SELECT count(*) INTO v_service_count
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prokind = 'f'
    AND has_function_privilege('service_role', p.oid, 'EXECUTE');

  IF v_service_count <> 74 THEN
    RAISE EXCEPTION 'ACL verification failed: service_role access drifted; expected 74, found %.', v_service_count;
  END IF;
END
$verify$;

-- Intentionally no COMMIT in this review draft.
-- The operator must review the transaction and explicitly choose COMMIT
-- in a separately approved rollout artifact, or ROLLBACK during rehearsal.
ROLLBACK;
