-- PHASE 16 — ROLLBACK SQL GENERATOR
-- DESIGN ONLY. DO NOT EXECUTE generated output without review.
-- This query consumes the exact JSON emitted by phase-16-acl-snapshot.sql.
-- Paste the complete JSON object into the dollar-quoted placeholder.
-- The query emits SQL text only; it does not execute GRANT/REVOKE statements.

WITH raw_snapshot AS (
  SELECT $phase16_snapshot$
PASTE_EXPORTED_PHASE16_SNAPSHOT_JSON_HERE
$phase16_snapshot$::jsonb AS wrapper
),
snapshot AS (
  SELECT COALESCE(wrapper->'snapshot', wrapper) AS doc FROM raw_snapshot
),
table_grants AS (
  SELECT
    'SET ROLE ' || quote_ident(g->>'grantor') || E';\n' ||
    'GRANT ' || upper(g->>'privilege') ||
    ' ON TABLE public.' || quote_ident(t->>'name') ||
    ' TO ' || CASE WHEN g->>'grantee'='PUBLIC' THEN 'PUBLIC' ELSE quote_ident(g->>'grantee') END ||
    CASE WHEN (g->>'is_grantable')::boolean THEN ' WITH GRANT OPTION' ELSE '' END ||
    ';\nRESET ROLE;' AS sql
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
    ';\nRESET ROLE;' AS sql
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
    ';\nRESET ROLE;' AS sql
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
    ';\nRESET ROLE;' AS sql
  FROM snapshot s
  CROSS JOIN LATERAL jsonb_array_elements(s.doc->'default_privileges') d
  CROSS JOIN LATERAL jsonb_array_elements(d->'acl') g
  WHERE g->>'grantee' IN ('anon','authenticated')
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
  SELECT 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || quote_ident(o.owner_name) ||
         ' REVOKE ALL ON SEQUENCES FROM anon, authenticated;'
  FROM (VALUES ('postgres'),('supabase_admin')) o(owner_name)
  UNION ALL
  SELECT 'ALTER DEFAULT PRIVILEGES FOR ROLE ' || quote_ident(o.owner_name) ||
         ' IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;'
  FROM (VALUES ('postgres'),('supabase_admin')) o(owner_name)
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
    OR (SELECT (doc->>'found_table_count')::integer FROM snapshot) <> 12
    OR (SELECT (doc->>'found_sequence_count')::integer FROM snapshot) <> 3
    OR (SELECT (doc->>'bootstrap_staging_sentinel')::boolean FROM snapshot) IS DISTINCT FROM true
    OR (SELECT jsonb_array_length(doc->'default_privileges') FROM snapshot) <> 4
  THEN 'ERROR: snapshot validation failed; do not use rollback output'
  ELSE string_agg(sql, E'\n\n' ORDER BY ord, sql) ||
       E'\n\n-- Verify restored ACLs against original snapshot. COMMIT only after exact review.'
END AS generated_rollback_sql
FROM all_restore;

-- Before executing generated SQL:
-- 1. Confirm the snapshot has 12 tables, 3 sequences and 4 default-ACL scopes.
-- 2. Confirm Staging identity in the snapshot and in the Supabase dashboard.
-- 3. Confirm each SET ROLE grantor can be assumed by the execution principal.
-- 4. Review that only anon/authenticated grants are restored; service_role and owner
--    ACLs were not changed by the proposed remediation and are intentionally untouched.
-- 5. Execute generated output in one transaction, then run the snapshot query again
--    and compare client-role ACL entries with the original snapshot.
