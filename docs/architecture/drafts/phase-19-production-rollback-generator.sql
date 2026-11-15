-- PHASE 19 — PRODUCTION ROLLBACK SQL GENERATOR
-- DESIGN ONLY. DO NOT EXECUTE generated output without review.
-- This query consumes the exact JSON emitted by phase-18-production-acl-snapshot.sql.
-- Paste the complete JSON object into the dollar-quoted placeholder.
-- The query emits SQL text only; it does not execute GRANT/REVOKE statements.

WITH raw_snapshot AS (
  SELECT $phase16_snapshot$
PASTE_EXPORTED_PHASE16_SNAPSHOT_JSON_HERE
$phase16_snapshot$::jsonb AS wrapper
),
snapshot AS (
  SELECT COALESCE(wrapper->'snapshot', wrapper) AS doc, wrapper FROM raw_snapshot
),
table_grants AS (
  SELECT
    'SET ROLE ' || quote_ident(g->>'grantor') || E';\n' ||
    'GRANT ' || upper(g->>'privilege') ||
    ' ON TABLE public.' || quote_ident(t->>'name') ||
    ' TO ' || CASE WHEN g->>'grantee'='PUBLIC' THEN 'PUBLIC' ELSE quote_ident(g->>'grantee') END ||
    CASE WHEN (g->>'is_grantable')::boolean THEN ' WITH GRANT OPTION' ELSE '' END ||
    E';\nRESET ROLE;' AS sql
  FROM snapshot s
  CROSS JOIN LATERAL jsonb_array_elements(s.doc->'tables') t
  CROSS JOIN LATERAL jsonb_array_elements(t->'acl') g
  WHERE g->>'grantee' IN ('anon','authenticated')
),
column_grants AS (
  SELECT
    'SET ROLE ' || quote_ident(g->>'grantor') || E';\n' ||
    'GRANT ' || upper(g->>'privilege') ||
    ' (' || quote_ident(c->>'column_name') || ') ON TABLE public.' ||
    quote_ident(c->>'table_name') ||
    ' TO ' || CASE WHEN g->>'grantee'='PUBLIC' THEN 'PUBLIC' ELSE quote_ident(g->>'grantee') END ||
    CASE WHEN (g->>'is_grantable')::boolean THEN ' WITH GRANT OPTION' ELSE '' END ||
    E';\nRESET ROLE;' AS sql
  FROM snapshot s
  CROSS JOIN LATERAL jsonb_array_elements(s.doc->'columns') c
  CROSS JOIN LATERAL jsonb_array_elements(c->'acl') g
  WHERE g->>'grantee' IN ('anon','authenticated')
),
sequence_grants AS (
  SELECT
    'SET ROLE ' || quote_ident(g->>'grantor') || E';\n' ||
    'GRANT ' || upper(g->>'privilege') ||
    ' ON SEQUENCE public.' || quote_ident(q->>'name') ||
    ' TO ' || CASE WHEN g->>'grantee'='PUBLIC' THEN 'PUBLIC' ELSE quote_ident(g->>'grantee') END ||
    CASE WHEN (g->>'is_grantable')::boolean THEN ' WITH GRANT OPTION' ELSE '' END ||
    E';\nRESET ROLE;' AS sql
  FROM snapshot s
  CROSS JOIN LATERAL jsonb_array_elements(s.doc->'sequences') q
  CROSS JOIN LATERAL jsonb_array_elements(q->'acl') g
  WHERE g->>'grantee' IN ('anon','authenticated')
),
default_grants AS (
  SELECT
    'SET ROLE ' || quote_ident(g->>'grantor') || E';\n' ||
    'ALTER DEFAULT PRIVILEGES FOR ROLE ' || quote_ident(d->>'owner') ||
    CASE WHEN d->>'scope'='public' THEN ' IN SCHEMA public' ELSE '' END ||
    ' GRANT ' || upper(g->>'privilege') ||
    ' ON SEQUENCES TO ' ||
    CASE WHEN g->>'grantee'='PUBLIC' THEN 'PUBLIC' ELSE quote_ident(g->>'grantee') END ||
    CASE WHEN (g->>'is_grantable')::boolean THEN ' WITH GRANT OPTION' ELSE '' END ||
    E';\nRESET ROLE;' AS sql
  FROM snapshot s
  CROSS JOIN LATERAL jsonb_array_elements(s.doc->'default_privileges') d
  CROSS JOIN LATERAL jsonb_array_elements(d->'acl') g
  WHERE d->>'owner'='postgres'
    AND g->>'grantee' IN ('anon','authenticated')
),
unexpected_grantors AS (
  SELECT g->>'grantor' AS grantor
  FROM snapshot s
  CROSS JOIN LATERAL jsonb_array_elements(s.doc->'tables') t
  CROSS JOIN LATERAL jsonb_array_elements(t->'acl') g
  WHERE g->>'grantee' IN ('anon','authenticated')
  UNION ALL
  SELECT g->>'grantor'
  FROM snapshot s
  CROSS JOIN LATERAL jsonb_array_elements(s.doc->'columns') c
  CROSS JOIN LATERAL jsonb_array_elements(c->'acl') g
  WHERE g->>'grantee' IN ('anon','authenticated')
  UNION ALL
  SELECT g->>'grantor'
  FROM snapshot s
  CROSS JOIN LATERAL jsonb_array_elements(s.doc->'sequences') q
  CROSS JOIN LATERAL jsonb_array_elements(q->'acl') g
  WHERE g->>'grantee' IN ('anon','authenticated')
  UNION ALL
  SELECT g->>'grantor'
  FROM snapshot s
  CROSS JOIN LATERAL jsonb_array_elements(s.doc->'default_privileges') d
  CROSS JOIN LATERAL jsonb_array_elements(d->'acl') g
  WHERE d->>'owner'='postgres' AND g->>'grantee' IN ('anon','authenticated')
),
revoke_baseline AS (
  SELECT
    'REVOKE ALL PRIVILEGES ON TABLE public.' || quote_ident(x.name) ||
    ' FROM anon, authenticated;' AS sql
  FROM (VALUES
    ('attempt_answers'),('attempt_question_times'),('attempts'),('audit_logs'),
    ('exam_solutions'),('exam_version_questions'),('exam_versions'),('exams'),
    ('profiles'),('question_answer_keys'),('question_versions'),('questions')
  ) x(name)
  UNION ALL
  SELECT 'REVOKE UPDATE (display_name) ON TABLE public.profiles FROM anon, authenticated;'
  UNION ALL
  SELECT 'REVOKE ALL PRIVILEGES ON SEQUENCE public.' || quote_ident(x.name) ||
         ' FROM anon, authenticated;'
  FROM (VALUES ('audit_logs_id_seq'),('import_events_id_seq'),('tsa_user_code_seq')) x(name)
  UNION ALL
  SELECT 'ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON SEQUENCES FROM anon, authenticated;'
  UNION ALL
  SELECT 'ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;'
),
all_restore AS (
  SELECT -1 AS ord, 'BEGIN;' AS sql
  UNION ALL SELECT 0, sql FROM revoke_baseline
  UNION ALL SELECT 1, sql FROM table_grants
  UNION ALL SELECT 2, sql FROM column_grants
  UNION ALL SELECT 3, sql FROM sequence_grants
  UNION ALL SELECT 4, sql FROM default_grants
)
SELECT CASE
  WHEN (SELECT doc->>'snapshot_format' FROM snapshot) <> 'phase16-acl-snapshot-v1'
    OR (SELECT wrapper->>'snapshot_fingerprint_md5' FROM snapshot) IS DISTINCT FROM
       (SELECT md5(doc::text) FROM snapshot)
    OR (SELECT (doc->>'expected_table_count')::integer FROM snapshot) <> 12
    OR (SELECT (doc->>'found_table_count')::integer FROM snapshot) <> 12
    OR (SELECT (doc->>'found_sequence_count')::integer FROM snapshot) <> 3
    OR (SELECT (doc->>'bootstrap_staging_sentinel')::boolean FROM snapshot) IS DISTINCT FROM false
    OR (SELECT doc->>'bootstrap_definition_md5' FROM snapshot) IS DISTINCT FROM 'af408493755e9b37e2e3365206d86f06'
    OR (SELECT jsonb_array_length(doc->'default_privileges') FROM snapshot) <> 4
    OR (SELECT d->>'raw_acl' FROM snapshot s CROSS JOIN LATERAL jsonb_array_elements(s.doc->'default_privileges') d WHERE d->>'owner'='supabase_admin' AND d->>'scope'='public') IS DISTINCT FROM
       '{postgres=rwU/supabase_admin,anon=rwU/supabase_admin,authenticated=rwU/supabase_admin,service_role=rwU/supabase_admin}'
    OR EXISTS (SELECT 1 FROM unexpected_grantors WHERE grantor <> 'postgres')
  THEN 'ERROR: snapshot validation failed; do not use rollback output'
  ELSE E'DO $phase19_rollback_role_guard$\nBEGIN\n  IF current_user <> ''postgres''\n     AND NOT pg_has_role(current_user, ''postgres'', ''SET'')\n     AND NOT COALESCE((SELECT rolsuper FROM pg_roles WHERE rolname=current_user), false) THEN\n    RAISE EXCEPTION ''Rollback blocked: executor cannot SET ROLE postgres'';\n  END IF;\nEND\n$phase19_rollback_role_guard$;\n\n' || string_agg(sql, E'\n\n' ORDER BY ord, sql) ||
       E'\n\n-- Verify restored ACLs against original snapshot. COMMIT only after exact review.'
END AS generated_rollback_sql
FROM all_restore;

-- Before executing generated SQL:
-- 1. Confirm the snapshot has 12 tables, 3 sequences and 4 default-ACL scopes.
-- 2. Confirm Production bootstrap definition fingerprint and Supabase project ref hwqtsopvpucadgpkigqz.
-- 3. Confirm all target ACL grantors are postgres; platform-managed
--    supabase_admin defaults are validated but intentionally excluded from SQL.
-- 4. Confirm the executor can SET ROLE postgres. Never attempt to assume
--    supabase_admin or rewrite its grantor. service_role and owner ACLs are untouched.
-- 5. Execute generated output in one transaction, then run the snapshot query again
--    and compare client-role ACL entries with the original snapshot.
