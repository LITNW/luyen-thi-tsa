-- Minimal isolated PostgreSQL schema for migration regression tests.
-- This is a test fixture, not a production schema migration.

DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END;
$roles$;

CREATE SCHEMA IF NOT EXISTS auth;

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $function$
  SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$function$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $function$
  SELECT true
$function$;

CREATE TABLE public.exams (
  id uuid PRIMARY KEY
);

CREATE TABLE public.questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope text NOT NULL,
  owner_exam_id uuid,
  created_by uuid
);

CREATE TABLE public.question_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL REFERENCES public.questions(id),
  version_no integer NOT NULL,
  question_type text NOT NULL,
  content jsonb NOT NULL,
  created_by uuid
);

CREATE TABLE public.question_answer_keys (
  question_version_id uuid PRIMARY KEY REFERENCES public.question_versions(id),
  answer_key jsonb NOT NULL,
  explanation text NOT NULL DEFAULT '',
  grading_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  source_metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE public.exam_versions (
  id uuid PRIMARY KEY,
  status text NOT NULL,
  published_by uuid,
  published_at timestamptz
);

CREATE TABLE public.exam_version_questions (
  exam_version_id uuid NOT NULL REFERENCES public.exam_versions(id),
  question_version_id uuid NOT NULL REFERENCES public.question_versions(id),
  position integer NOT NULL,
  PRIMARY KEY (exam_version_id,question_version_id)
);
