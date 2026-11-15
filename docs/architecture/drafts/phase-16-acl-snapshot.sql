-- PHASE 16 — READ-ONLY ACL SNAPSHOT
-- Target: Staging project cppalwtdkditlhojpeyc
-- This file contains SELECT statements only. It does not mutate database state.
-- Export and retain the complete JSON result before any future ACL rehearsal.

WITH
expected_tables(name) AS (
  VALUES
    ('attempt_answers'), ('attempt_question_times'), ('attempts'),
    ('audit_logs'), ('exam_solutions'), ('exam_version_questions'),
    ('exam_versions'), ('exams'), ('profiles'), ('question_answer_keys'),
    ('question_versions'), ('questions')
),
expected_sequences(name) AS (
  VALUES ('audit_logs_id_seq'), ('import_events_id_seq'), ('tsa_user_code_seq')
),
table_rows AS (
  SELECT c.relname AS name, pg_get_userbyid(c.relowner) AS owner,
         COALESCE((
           SELECT jsonb_agg(jsonb_build_object(
             'grantor', CASE WHEN x.grantor=0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantor) END,
             'grantee', CASE WHEN x.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END,
             'privilege', x.privilege_type,
             'is_grantable', x.is_grantable
           ) ORDER BY x.grantee, x.privilege_type)
           FROM aclexplode(COALESCE(c.relacl, acldefault('r', c.relowner))) x
         ), '[]'::jsonb) AS acl
  FROM pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind IN ('r','p')
    AND c.relname IN (SELECT name FROM expected_tables)
),
column_rows AS (
  SELECT c.relname AS table_name, a.attname AS column_name,
         COALESCE((
           SELECT jsonb_agg(jsonb_build_object(
             'grantor', pg_get_userbyid(x.grantor),
             'grantee', CASE WHEN x.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END,
             'privilege', x.privilege_type,
             'is_grantable', x.is_grantable
           ) ORDER BY x.grantee, x.privilege_type)
           FROM aclexplode(a.attacl) x
         ), '[]'::jsonb) AS acl
  FROM pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace
  JOIN pg_attribute a ON a.attrelid=c.oid
  WHERE n.nspname='public' AND c.relname='profiles'
    AND a.attname='display_name' AND a.attnum>0 AND NOT a.attisdropped
),
sequence_rows AS (
  SELECT c.relname AS name, pg_get_userbyid(c.relowner) AS owner,
         COALESCE((
           SELECT jsonb_agg(jsonb_build_object(
             'grantor', CASE WHEN x.grantor=0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantor) END,
             'grantee', CASE WHEN x.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END,
             'privilege', x.privilege_type,
             'is_grantable', x.is_grantable
           ) ORDER BY x.grantee, x.privilege_type)
           FROM aclexplode(COALESCE(c.relacl, acldefault('S', c.relowner))) x
         ), '[]'::jsonb) AS acl
  FROM pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind='S'
    AND c.relname IN (SELECT name FROM expected_sequences)
),
default_scopes(owner_name, scope_name, schema_oid) AS (
  SELECT r.rolname, s.scope_name, s.schema_oid
  FROM (VALUES ('postgres'), ('supabase_admin')) r(rolname)
  CROSS JOIN (
    VALUES ('global', 0::oid), ('public', 'public'::regnamespace::oid)
  ) s(scope_name, schema_oid)
),
default_rows AS (
  SELECT ds.owner_name AS owner, ds.scope_name AS scope,
         d.defaclacl::text AS raw_acl,
         COALESCE((
           SELECT jsonb_agg(jsonb_build_object(
             'grantor', pg_get_userbyid(x.grantor),
             'grantee', CASE WHEN x.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END,
             'privilege', x.privilege_type,
             'is_grantable', x.is_grantable
           ) ORDER BY x.grantee, x.privilege_type)
           FROM aclexplode(d.defaclacl) x
         ), '[]'::jsonb) AS acl,
         (d.oid IS NOT NULL) AS has_catalog_override
  FROM default_scopes ds
  LEFT JOIN pg_roles r ON r.rolname=ds.owner_name
  LEFT JOIN pg_default_acl d
    ON d.defaclrole=r.oid
   AND d.defaclnamespace=ds.schema_oid
   AND d.defaclobjtype='S'
)
, payload AS (
SELECT jsonb_build_object(
  'snapshot_format', 'phase16-acl-snapshot-v1',
  'captured_at', clock_timestamp(),
  'database', current_database(),
  'server_version', current_setting('server_version'),
  'bootstrap_staging_sentinel', (
    SELECT position('staging-admin@example.test' IN pg_get_functiondef(p.oid)) > 0
    FROM pg_proc p
    WHERE p.oid='public.bootstrap_first_admin()'::regprocedure
  ),
  'expected_table_count', (SELECT count(*) FROM expected_tables),
  'found_table_count', (SELECT count(*) FROM table_rows),
  'tables', COALESCE((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.name) FROM table_rows t), '[]'::jsonb),
  'columns', COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.table_name,c.column_name) FROM column_rows c), '[]'::jsonb),
  'expected_sequence_count', (SELECT count(*) FROM expected_sequences),
  'found_sequence_count', (SELECT count(*) FROM sequence_rows),
  'sequences', COALESCE((SELECT jsonb_agg(to_jsonb(s) ORDER BY s.name) FROM sequence_rows s), '[]'::jsonb),
  'default_privileges', COALESCE((SELECT jsonb_agg(to_jsonb(d) ORDER BY d.owner,d.scope) FROM default_rows d), '[]'::jsonb)
) AS doc
)
SELECT jsonb_pretty(jsonb_build_object(
  'snapshot_fingerprint_md5', md5(doc::text),
  'snapshot', doc
)) AS phase16_acl_snapshot
FROM payload;
