-- PHASE 16 — STAGING ACL REMEDIATION DRAFT
-- DESIGN ONLY. DO NOT EXECUTE.
-- The first statement intentionally raises an exception. Removing this guard
-- requires external-caller clearance, snapshot export, peer review and separate approval.

-- Executed runtime copy for the explicitly approved Staging rehearsal on 2026-11-15.
-- Project: cppalwtdkditlhojpeyc. Production is explicitly excluded.
-- The following is the reviewed target sequence, not yet authorized to run.
-- Keep all statements in one transaction. Never run against Production.

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

DO $phase16_preflight$
DECLARE
  v_table_count integer;
  v_sequence_count integer;
  v_staging_sentinel boolean;
  v_target_owner_count integer;
  v_platform_owned_public_count integer;
  v_can_manage_postgres boolean;
  v_platform_sequence_default_acl text;
  v_has_public_acl boolean;
  v_has_public_column_acl boolean;
  v_has_public_default_acl boolean;
BEGIN
  IF current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'Unexpected database name: %', current_database();
  END IF;

  SELECT position('staging-admin@example.test' IN pg_get_functiondef(p.oid)) > 0
    INTO v_staging_sentinel
  FROM pg_proc p
  WHERE p.oid='public.bootstrap_first_admin()'::regprocedure;

  IF NOT COALESCE(v_staging_sentinel,false) THEN
    RAISE EXCEPTION 'Staging bootstrap sentinel missing; wrong project or unexpected function body';
  END IF;

  SELECT count(*) INTO v_table_count
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind IN ('r','p')
    AND c.relname = ANY(ARRAY[
      'attempt_answers','attempt_question_times','attempts','audit_logs',
      'exam_solutions','exam_version_questions','exam_versions','exams',
      'profiles','question_answer_keys','question_versions','questions'
    ]);

  IF v_table_count <> 12 THEN
    RAISE EXCEPTION 'Expected 12 target tables; found %', v_table_count;
  END IF;

  SELECT count(*) INTO v_sequence_count
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind='S'
    AND c.relname = ANY(ARRAY['audit_logs_id_seq','import_events_id_seq','tsa_user_code_seq']);

  IF v_sequence_count <> 3 THEN
    RAISE EXCEPTION 'Expected 3 target sequences; found %', v_sequence_count;
  END IF;

  -- All current target relations/sequences must remain postgres-owned.
  SELECT count(*) INTO v_target_owner_count
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public'
    AND c.relname = ANY(ARRAY[
      'attempt_answers','attempt_question_times','attempts','audit_logs',
      'exam_solutions','exam_version_questions','exam_versions','exams',
      'profiles','question_answer_keys','question_versions','questions',
      'audit_logs_id_seq','import_events_id_seq','tsa_user_code_seq'
    ])
    AND c.relowner='postgres'::regrole;

  IF v_target_owner_count <> 15 THEN
    RAISE EXCEPTION 'Expected all 15 target objects to be postgres-owned; found %', v_target_owner_count;
  END IF;

  -- Any platform-owned relation or function in public requires separate review.
  SELECT
    (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='public' AND c.relowner='supabase_admin'::regrole
       AND c.relkind IN ('r','p','v','m','S','f'))
    +
    (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
     WHERE n.nspname='public' AND p.proowner='supabase_admin'::regrole)
    INTO v_platform_owned_public_count;

  IF v_platform_owned_public_count <> 0 THEN
    RAISE EXCEPTION 'Found % supabase_admin-owned public relations/functions; separate platform-object review required',
      v_platform_owned_public_count;
  END IF;

  -- Capture the platform-managed default ACL as an immutable baseline.
  SELECT d.defaclacl::text INTO v_platform_sequence_default_acl
  FROM pg_default_acl d
  WHERE d.defaclrole='supabase_admin'::regrole
    AND d.defaclnamespace='public'::regnamespace
    AND d.defaclobjtype='S';

  IF v_platform_sequence_default_acl IS DISTINCT FROM
     '{postgres=rwU/supabase_admin,anon=rwU/supabase_admin,authenticated=rwU/supabase_admin,service_role=rwU/supabase_admin}' THEN
    RAISE EXCEPTION 'Unexpected supabase_admin/public sequence default ACL; platform-managed scope requires separate review';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_attribute a
    WHERE a.attrelid='public.profiles'::regclass
      AND a.attname='display_name' AND a.attnum>0 AND NOT a.attisdropped
  ) THEN
    RAISE EXCEPTION 'profiles.display_name not found';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon')
     OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated')
     OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='postgres')
     OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='supabase_admin') THEN
    RAISE EXCEPTION 'One or more expected roles are missing';
  END IF;

  SELECT rolsuper OR pg_has_role(current_user, 'postgres', 'MEMBER')
    INTO v_can_manage_postgres
  FROM pg_roles WHERE rolname=current_user;

  IF NOT COALESCE(v_can_manage_postgres,false) THEN
    RAISE EXCEPTION 'Executor cannot manage default privileges for postgres; stop and use an authorized operator';
  END IF;

  -- Fail closed on PUBLIC ACLs rather than broadening the scope of revocation.
  SELECT EXISTS (
    SELECT 1
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault((CASE WHEN c.relkind='S' THEN 'S' ELSE 'r' END)::"char", c.relowner))) x
    WHERE n.nspname='public'
      AND (
        (c.relkind IN ('r','p') AND c.relname = ANY(ARRAY[
          'attempt_answers','attempt_question_times','attempts','audit_logs',
          'exam_solutions','exam_version_questions','exam_versions','exams',
          'profiles','question_answer_keys','question_versions','questions'
        ]))
        OR (c.relkind='S' AND c.relname = ANY(ARRAY[
          'audit_logs_id_seq','import_events_id_seq','tsa_user_code_seq'
        ]))
      )
      AND x.grantee=0
  ) INTO v_has_public_acl;

  IF v_has_public_acl THEN
    RAISE EXCEPTION 'Unexpected PUBLIC ACL found on a target object; expand review before remediation';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    JOIN pg_attribute a ON a.attrelid=c.oid
    CROSS JOIN LATERAL aclexplode(a.attacl) x
    WHERE n.nspname='public' AND c.relname='profiles'
      AND a.attname='display_name' AND a.attnum>0 AND NOT a.attisdropped
      AND x.grantee=0
  ) INTO v_has_public_column_acl;

  IF v_has_public_column_acl THEN
    RAISE EXCEPTION 'Unexpected PUBLIC column ACL found on profiles.display_name';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM pg_default_acl d
    JOIN pg_roles r ON r.oid=d.defaclrole
    CROSS JOIN LATERAL aclexplode(d.defaclacl) x
    WHERE r.rolname IN ('postgres','supabase_admin')
      AND d.defaclobjtype='S'
      AND d.defaclnamespace IN (0,'public'::regnamespace)
      AND x.grantee=0
  ) INTO v_has_public_default_acl;

  IF v_has_public_default_acl THEN
    RAISE EXCEPTION 'Unexpected PUBLIC sequence default ACL found; expand review before remediation';
  END IF;
END
$phase16_preflight$;

-- Capture/export the read-only snapshot immediately before this transaction.
-- Compare it with the reviewed snapshot fixture before uncommenting any change.

REVOKE ALL PRIVILEGES ON TABLE
  public.attempt_answers,
  public.attempt_question_times,
  public.attempts,
  public.audit_logs,
  public.exam_solutions,
  public.exam_version_questions,
  public.exam_versions,
  public.exams,
  public.profiles,
  public.question_answer_keys,
  public.question_versions,
  public.questions
FROM anon, authenticated;

GRANT SELECT ON TABLE public.profiles, public.exams TO authenticated;

REVOKE UPDATE (display_name) ON TABLE public.profiles FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON SEQUENCE
  public.audit_logs_id_seq,
  public.import_events_id_seq,
  public.tsa_user_code_seq
FROM anon, authenticated;

-- Only postgres-owned defaults are mutable by this project execution identity.
-- Global and schema-specific scopes are both addressed because schema defaults
-- add to global defaults; a schema-level REVOKE cannot cancel a global GRANT.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;

-- Intentionally do not ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin.
-- Supabase reserves that platform role; its defaults apply only to objects it creates.
-- Current target objects are all owned by postgres. Verify platform ACL remains unchanged.

DO $phase16_postflight$
DECLARE
  v_bad boolean;
BEGIN
  -- anon: zero effective privileges on all target tables.
  SELECT EXISTS (
    SELECT 1
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relname = ANY(ARRAY[
        'attempt_answers','attempt_question_times','attempts','audit_logs',
        'exam_solutions','exam_version_questions','exam_versions','exams',
        'profiles','question_answer_keys','question_versions','questions'
      ])
      AND (
        has_table_privilege('anon',c.oid,'SELECT')
        OR has_table_privilege('anon',c.oid,'INSERT')
        OR has_table_privilege('anon',c.oid,'UPDATE')
        OR has_table_privilege('anon',c.oid,'DELETE')
        OR has_table_privilege('anon',c.oid,'TRUNCATE')
        OR has_table_privilege('anon',c.oid,'REFERENCES')
        OR has_table_privilege('anon',c.oid,'TRIGGER')
        OR has_table_privilege('anon',c.oid,'MAINTAIN')
      )
  ) INTO v_bad;
  IF v_bad THEN RAISE EXCEPTION 'Postflight failed: anon retains target table privilege'; END IF;

  -- authenticated: SELECT only on profiles/exams, zero rights on the other ten.
  SELECT EXISTS (
    SELECT 1
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relname = ANY(ARRAY[
        'attempt_answers','attempt_question_times','attempts','audit_logs',
        'exam_solutions','exam_version_questions','exam_versions',
        'question_answer_keys','question_versions','questions'
      ])
      AND (
        has_table_privilege('authenticated',c.oid,'SELECT')
        OR has_table_privilege('authenticated',c.oid,'INSERT')
        OR has_table_privilege('authenticated',c.oid,'UPDATE')
        OR has_table_privilege('authenticated',c.oid,'DELETE')
        OR has_table_privilege('authenticated',c.oid,'TRUNCATE')
        OR has_table_privilege('authenticated',c.oid,'REFERENCES')
        OR has_table_privilege('authenticated',c.oid,'TRIGGER')
        OR has_table_privilege('authenticated',c.oid,'MAINTAIN')
      )
  ) INTO v_bad;
  IF v_bad THEN RAISE EXCEPTION 'Postflight failed: authenticated retains privilege on restricted table'; END IF;

  IF NOT has_table_privilege('authenticated','public.profiles','SELECT')
     OR NOT has_table_privilege('authenticated','public.exams','SELECT') THEN
    RAISE EXCEPTION 'Postflight failed: required authenticated SELECT is missing';
  END IF;

  IF has_table_privilege('authenticated','public.profiles','INSERT')
     OR has_table_privilege('authenticated','public.profiles','UPDATE')
     OR has_table_privilege('authenticated','public.profiles','DELETE')
     OR has_table_privilege('authenticated','public.profiles','TRUNCATE')
     OR has_table_privilege('authenticated','public.profiles','REFERENCES')
     OR has_table_privilege('authenticated','public.profiles','TRIGGER')
     OR has_table_privilege('authenticated','public.profiles','MAINTAIN')
     OR has_table_privilege('authenticated','public.exams','INSERT')
     OR has_table_privilege('authenticated','public.exams','UPDATE')
     OR has_table_privilege('authenticated','public.exams','DELETE')
     OR has_table_privilege('authenticated','public.exams','TRUNCATE')
     OR has_table_privilege('authenticated','public.exams','REFERENCES')
     OR has_table_privilege('authenticated','public.exams','TRIGGER')
     OR has_table_privilege('authenticated','public.exams','MAINTAIN') THEN
    RAISE EXCEPTION 'Postflight failed: unexpected authenticated write privilege remains';
  END IF;

  IF has_column_privilege('anon','public.profiles','display_name','UPDATE')
     OR has_column_privilege('authenticated','public.profiles','display_name','UPDATE') THEN
    RAISE EXCEPTION 'Postflight failed: display_name UPDATE remains effective';
  END IF;

  IF has_sequence_privilege('anon','public.audit_logs_id_seq','USAGE')
     OR has_sequence_privilege('anon','public.audit_logs_id_seq','SELECT')
     OR has_sequence_privilege('anon','public.audit_logs_id_seq','UPDATE')
     OR has_sequence_privilege('authenticated','public.audit_logs_id_seq','USAGE')
     OR has_sequence_privilege('authenticated','public.audit_logs_id_seq','SELECT')
     OR has_sequence_privilege('authenticated','public.audit_logs_id_seq','UPDATE')
     OR has_sequence_privilege('anon','public.import_events_id_seq','USAGE')
     OR has_sequence_privilege('anon','public.import_events_id_seq','SELECT')
     OR has_sequence_privilege('anon','public.import_events_id_seq','UPDATE')
     OR has_sequence_privilege('authenticated','public.import_events_id_seq','USAGE')
     OR has_sequence_privilege('authenticated','public.import_events_id_seq','SELECT')
     OR has_sequence_privilege('authenticated','public.import_events_id_seq','UPDATE')
     OR has_sequence_privilege('anon','public.tsa_user_code_seq','USAGE')
     OR has_sequence_privilege('anon','public.tsa_user_code_seq','SELECT')
     OR has_sequence_privilege('anon','public.tsa_user_code_seq','UPDATE')
     OR has_sequence_privilege('authenticated','public.tsa_user_code_seq','USAGE')
     OR has_sequence_privilege('authenticated','public.tsa_user_code_seq','SELECT')
     OR has_sequence_privilege('authenticated','public.tsa_user_code_seq','UPDATE') THEN
    RAISE EXCEPTION 'Postflight failed: client sequence privilege remains';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_default_acl d
    JOIN pg_roles r ON r.oid=d.defaclrole
    CROSS JOIN LATERAL aclexplode(d.defaclacl) x
    WHERE r.rolname='postgres'
      AND d.defaclobjtype='S'
      AND d.defaclnamespace IN (0,'public'::regnamespace)
      AND x.grantee IN ('anon'::regrole,'authenticated'::regrole)
  ) THEN
    RAISE EXCEPTION 'Postflight failed: client role remains in postgres sequence default ACL';
  END IF;

  -- Platform-managed defaults are an explicit exception, not an ACL target.
  IF (SELECT d.defaclacl::text FROM pg_default_acl d
      WHERE d.defaclrole='supabase_admin'::regrole
        AND d.defaclnamespace='public'::regnamespace
        AND d.defaclobjtype='S') IS DISTINCT FROM
     '{postgres=rwU/supabase_admin,anon=rwU/supabase_admin,authenticated=rwU/supabase_admin,service_role=rwU/supabase_admin}' THEN
    RAISE EXCEPTION 'Postflight failed: supabase_admin platform default ACL changed unexpectedly';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_default_acl d
             WHERE d.defaclrole='supabase_admin'::regrole
               AND d.defaclnamespace=0 AND d.defaclobjtype='S') THEN
    RAISE EXCEPTION 'Postflight failed: unexpected global supabase_admin sequence default ACL appeared';
  END IF;
END
$phase16_postflight$;

-- Only a future, separately approved rehearsal may replace this ROLLBACK
-- with COMMIT after postflight, E2E plan and operator confirmation.
COMMIT;
