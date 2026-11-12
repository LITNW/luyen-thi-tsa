-- Isolated PostgreSQL fixture matching the live columns and relevant constraints.
-- This is test-only schema; it does not create or modify Production objects.

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
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 240),
  description text NOT NULL DEFAULT '',
  duration_minutes integer NOT NULL CHECK (duration_minutes BETWEEN 1 AND 600),
  questions_public jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(questions_public) = 'array'),
  is_published boolean NOT NULL DEFAULT false,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope text NOT NULL CHECK (scope IN ('bank','exam')),
  owner_exam_id uuid REFERENCES public.exams(id),
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (scope = 'bank' AND owner_exam_id IS NULL)
    OR (scope = 'exam' AND owner_exam_id IS NOT NULL)
  )
);

CREATE TABLE public.question_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL REFERENCES public.questions(id),
  version_no integer NOT NULL CHECK (version_no > 0),
  question_type text NOT NULL CHECK (question_type IN ('mc','ms','tf','num','dnd')),
  content jsonb NOT NULL CHECK (jsonb_typeof(content) = 'object' AND content ? 'q'),
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (question_id,version_no),
  UNIQUE (id,question_id)
);

CREATE TABLE public.question_answer_keys (
  question_version_id uuid PRIMARY KEY REFERENCES public.question_versions(id),
  answer_key jsonb NOT NULL,
  explanation text NOT NULL DEFAULT '',
  grading_config jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(grading_config) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  source_metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(source_metadata) = 'object')
);

CREATE TABLE public.exam_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_id uuid NOT NULL REFERENCES public.exams(id),
  version_no integer NOT NULL CHECK (version_no > 0),
  title text NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 240),
  description text NOT NULL DEFAULT '',
  duration_minutes integer NOT NULL CHECK (duration_minutes BETWEEN 1 AND 600),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  created_by uuid,
  published_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  archived_at timestamptz,
  CHECK (
    (status = 'draft' AND published_at IS NULL)
    OR (status = 'published' AND published_at IS NOT NULL)
  ),
  UNIQUE (exam_id,version_no),
  UNIQUE (id,exam_id)
);

CREATE TABLE public.exam_version_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_version_id uuid NOT NULL,
  exam_id uuid NOT NULL,
  question_version_id uuid NOT NULL,
  question_id uuid NOT NULL,
  position integer NOT NULL CHECK (position > 0),
  points numeric NOT NULL DEFAULT 1 CHECK (points > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (exam_version_id,exam_id) REFERENCES public.exam_versions(id,exam_id),
  FOREIGN KEY (question_version_id,question_id) REFERENCES public.question_versions(id,question_id),
  UNIQUE (exam_version_id,position),
  UNIQUE (exam_version_id,question_version_id)
);
