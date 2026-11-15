-- STAGING ONLY: Phase 12 ACL rehearsal
-- Project ref: cppalwtdkditlhojpeyc
-- Baseline captured 2026-11-15:
--   public functions=72; SECURITY DEFINER=46
--   effective anon=32; authenticated=68; service_role=72
--   anon-callable SECURITY DEFINER=9
--   non-internal public triggers=33
-- This script is NOT for Production. It intentionally excludes
-- Production-only abandon_exam_attempt(uuid) and save_exam_atomic(...).
-- Execute only after saving the companion rollback snapshot.
--
-- Default privileges:
--   Revoke PUBLIC EXECUTE globally for postgres-created functions,
--   then remove explicit anon/authenticated defaults in public.
--   Preserve service_role defaults and all other schema-specific defaults.
--   This prevents a newly created public function from inheriting anon
--   EXECUTE via PUBLIC, while not changing the storage schema's explicit
--   anon/authenticated default ACLs.

BEGIN;

DO $preflight$
DECLARE
  v_functions integer;
  v_sd integer;
  v_anon integer;
  v_auth integer;
  v_service integer;
  v_anon_sd integer;
  v_triggers integer;
BEGIN
  SELECT count(*),
         count(*) FILTER (WHERE prosecdef),
         count(*) FILTER (WHERE has_function_privilege('anon', oid, 'EXECUTE')),
         count(*) FILTER (WHERE has_function_privilege('authenticated', oid, 'EXECUTE')),
         count(*) FILTER (WHERE has_function_privilege('service_role', oid, 'EXECUTE')),
         count(*) FILTER (WHERE prosecdef AND has_function_privilege('anon', oid, 'EXECUTE'))
    INTO v_functions, v_sd, v_anon, v_auth, v_service, v_anon_sd
  FROM pg_proc
  WHERE pronamespace = 'public'::regnamespace AND prokind = 'f';

  SELECT count(*) INTO v_triggers
  FROM pg_trigger t
  JOIN pg_class c ON c.oid=t.tgrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE NOT t.tgisinternal AND n.nspname='public';

  IF (v_functions, v_sd, v_anon, v_auth, v_service, v_anon_sd, v_triggers)
     IS DISTINCT FROM (72, 46, 32, 68, 72, 9, 33) THEN
    RAISE EXCEPTION 'Staging ACL preflight mismatch: functions %, SD %, anon %, authenticated %, service_role %, anon SD %, triggers %.',
      v_functions, v_sd, v_anon, v_auth, v_service, v_anon_sd, v_triggers;
  END IF;

  IF to_regprocedure('public.abandon_exam_attempt(uuid)') IS NOT NULL THEN
    RAISE EXCEPTION 'Staging identity drift: abandon_exam_attempt(uuid) unexpectedly exists; regenerate the plan.';
  END IF;

  IF to_regprocedure('public.start_exam_attempt(uuid)') IS NULL
     OR to_regprocedure('public.save_attempt_answer(uuid,uuid,jsonb)') IS NULL
     OR to_regprocedure('public.record_attempt_question_time_v2(uuid,uuid,integer,integer,uuid)') IS NULL
     OR to_regprocedure('public.list_published_exams_for_education_subject(uuid)') IS NULL
     OR to_regprocedure('public.is_admin()') IS NULL THEN
    RAISE EXCEPTION 'Staging ACL preflight failed: a required function identity is missing.';
  END IF;
END
$preflight$;

-- Existing public functions: remove inherited PUBLIC and direct client grants.
-- Explicit service_role grants remain untouched.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public
  FROM PUBLIC, anon, authenticated;

-- Future functions created by postgres:
-- remove global PUBLIC default (required because schema-local REVOKE cannot
-- cancel a global default grant), then remove explicit client-role defaults
-- in public. service_role and non-public schema defaults remain unchanged.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;

-- Student / attempt APIs: 8 Staging identities.
GRANT EXECUTE ON FUNCTION public.get_my_attempt_history(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_attempt_state(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_published_exam(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_attempt_question_time_v2(uuid,uuid,integer,integer,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_attempt_question_time(uuid,uuid,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_attempt_answer(uuid,uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_exam_attempt(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_exam_attempt(uuid) TO authenticated;

-- Admin / authoring / reporting APIs: 26 Staging identities.
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

-- Authenticated catalogue/read/bootstrap APIs: 6 Staging identities.
GRANT EXECUTE ON FUNCTION public.bootstrap_first_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_active_exam_categories() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_active_subjects() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_published_exams_for_education_subject(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_published_exams() TO authenticated;

-- Post-change assertions.
DO $verify$
DECLARE
  v_anon integer;
  v_auth integer;
  v_service integer;
  v_triggers integer;
  v_public_default integer;
  v_client_default integer;
  v_service_default integer;
BEGIN
  SELECT count(*) FILTER (WHERE has_function_privilege('anon', oid, 'EXECUTE')),
         count(*) FILTER (WHERE has_function_privilege('authenticated', oid, 'EXECUTE')),
         count(*) FILTER (WHERE has_function_privilege('service_role', oid, 'EXECUTE'))
    INTO v_anon, v_auth, v_service
  FROM pg_proc
  WHERE pronamespace='public'::regnamespace AND prokind='f';

  SELECT count(*) INTO v_triggers
  FROM pg_trigger t
  JOIN pg_class c ON c.oid=t.tgrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE NOT t.tgisinternal AND n.nspname='public';

  IF (v_anon, v_auth, v_service, v_triggers) IS DISTINCT FROM (0, 40, 72, 33) THEN
    RAISE EXCEPTION 'Staging ACL verification failed: anon %, authenticated %, service_role %, triggers %.',
      v_anon, v_auth, v_service, v_triggers;
  END IF;

  SELECT count(*) INTO v_public_default
  FROM pg_default_acl d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) x
  WHERE d.defaclrole='postgres'::regrole
    AND d.defaclnamespace=0
    AND d.defaclobjtype='f'
    AND x.grantee=0
    AND x.privilege_type='EXECUTE';

  IF v_public_default <> 0 THEN
    RAISE EXCEPTION 'Global postgres function default still grants PUBLIC EXECUTE.';
  END IF;

  SELECT count(*) INTO v_client_default
  FROM pg_default_acl d
  JOIN pg_namespace n ON n.oid=d.defaclnamespace
  CROSS JOIN LATERAL aclexplode(d.defaclacl) x
  WHERE d.defaclrole='postgres'::regrole
    AND n.nspname='public'
    AND d.defaclobjtype='f'
    AND x.grantee IN ('anon'::regrole,'authenticated'::regrole)
    AND x.privilege_type='EXECUTE';

  IF v_client_default <> 0 THEN
    RAISE EXCEPTION 'Postgres public function defaults still grant anon/authenticated EXECUTE.';
  END IF;

  SELECT count(*) INTO v_service_default
  FROM pg_default_acl d
  JOIN pg_namespace n ON n.oid=d.defaclnamespace
  CROSS JOIN LATERAL aclexplode(d.defaclacl) x
  WHERE d.defaclrole='postgres'::regrole
    AND n.nspname='public'
    AND d.defaclobjtype='f'
    AND x.grantee='service_role'::regrole
    AND x.privilege_type='EXECUTE';

  IF v_service_default <> 1 THEN
    RAISE EXCEPTION 'service_role default EXECUTE grant was not preserved.';
  END IF;
END
$verify$;

COMMIT;
