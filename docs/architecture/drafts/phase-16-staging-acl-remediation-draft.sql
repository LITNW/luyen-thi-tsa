-- PHASE 16 — STAGING ACL REMEDIATION DRAFT
-- DESIGN ONLY. DO NOT EXECUTE.
-- The first statement intentionally raises an exception. Removing this guard
-- requires external-caller clearance, snapshot export, peer review and separate approval.

DO $phase16_design_guard$
BEGIN
  RAISE EXCEPTION 'PHASE 16 DESIGN ONLY: remediation is not authorized for execution';
END
$phase16_design_guard$;

-- The following is the reviewed target sequence, not yet authorized to run.
-- Keep all statements in one transaction. Never run against Production.

BEGIN;

DO $phase16_preflight$
DECLARE
  v_table_count integer;
  v_sequence_count integer;
  v_staging_sentinel boolean;
  v_has_supabase_admin boolean;
  v_can_manage_postgres boolean;
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

  SELECT rolsuper OR pg_has_role(current_user, 'supabase_admin', 'MEMBER')
    INTO v_has_supabase_admin
  FROM pg_roles WHERE rolname=current_user;

  IF NOT COALESCE(v_has_supabase_admin,false) THEN
    RAISE EXCEPTION 'Executor cannot manage default privileges for supabase_admin; stop and use an authorized operator';
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
    CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault(CASE WHEN c.relkind='S' THEN 'S' ELSE 'r' END, c.relowner))) x
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

-- Global and schema-specific defaults are both addressed.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;

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
    WHERE r.rolname IN ('postgres','supabase_admin')
      AND d.defaclobjtype='S'
      AND d.defaclnamespace IN (0,'public'::regnamespace)
      AND x.grantee IN ('anon'::regrole,'authenticated'::regrole)
  ) THEN
    RAISE EXCEPTION 'Postflight failed: client role remains in sequence default ACL';
  END IF;
END
$phase16_postflight$;

-- Only a future, separately approved rehearsal may replace this ROLLBACK
-- with COMMIT after postflight, E2E plan and operator confirmation.
ROLLBACK;
