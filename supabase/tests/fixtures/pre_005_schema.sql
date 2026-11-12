-- Test-only reconstruction of the schema state immediately before recorded migration 005.
-- Generated from Production catalog metadata; contains schema only, no user/exam/attempt rows.
-- This is not an original historical migration and is not intended to be applied to Production.

DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END;
$roles$;

CREATE SCHEMA IF NOT EXISTS auth;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

CREATE TABLE auth.users (
  id uuid PRIMARY KEY,
  email text,
  email_confirmed_at timestamptz,
  raw_user_meta_data jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE
AS $function$
  SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$function$;

CREATE OR REPLACE FUNCTION auth.role()
RETURNS text LANGUAGE sql STABLE
AS $function$
  SELECT nullif(current_setting('request.jwt.claim.role',true),'')
$function$;

CREATE OR REPLACE FUNCTION auth.jwt()
RETURNS jsonb LANGUAGE sql STABLE
AS $function$
  SELECT coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb
$function$;

CREATE SEQUENCE public.audit_logs_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 NO CYCLE;
CREATE SEQUENCE public.tsa_user_code_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 999999 CACHE 1 NO CYCLE;
CREATE TABLE public.attempt_answers (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  attempt_id uuid NOT NULL,
  exam_version_id uuid NOT NULL,
  exam_version_question_id uuid NOT NULL,
  answer jsonb NOT NULL,
  is_correct boolean,
  earned_points numeric(10,4),
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  graded_at timestamp with time zone,
  CONSTRAINT attempt_answers_answer_check CHECK (answer <> 'null'::jsonb),
  CONSTRAINT attempt_answers_attempt_question_unique UNIQUE (attempt_id, exam_version_question_id),
  CONSTRAINT attempt_answers_earned_points_check CHECK (earned_points IS NULL OR earned_points >= 0::numeric),
  CONSTRAINT attempt_answers_pkey PRIMARY KEY (id)
);

CREATE TABLE public.attempt_question_times (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  attempt_id uuid NOT NULL,
  exam_version_id uuid NOT NULL,
  exam_version_question_id uuid NOT NULL,
  seconds_spent integer DEFAULT 0 NOT NULL,
  visit_count integer DEFAULT 0 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT attempt_question_times_pkey PRIMARY KEY (id),
  CONSTRAINT attempt_question_times_seconds_spent_check CHECK (seconds_spent >= 0),
  CONSTRAINT attempt_question_times_unique UNIQUE (attempt_id, exam_version_question_id),
  CONSTRAINT attempt_question_times_visit_count_check CHECK (visit_count >= 0)
);

CREATE TABLE public.attempts (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  user_id uuid NOT NULL,
  exam_id uuid NOT NULL,
  answers jsonb DEFAULT '[]'::jsonb NOT NULL,
  score numeric(10,3) DEFAULT 0 NOT NULL,
  max_score numeric(10,3) NOT NULL,
  elapsed_seconds integer DEFAULT 0 NOT NULL,
  result_details jsonb DEFAULT '[]'::jsonb NOT NULL,
  submitted_at timestamp with time zone,
  exam_version_id uuid,
  status text DEFAULT 'in_progress'::text NOT NULL,
  started_at timestamp with time zone DEFAULT now() NOT NULL,
  finished_at timestamp with time zone,
  last_activity_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT attempts_answers_check CHECK (jsonb_typeof(answers) = 'array'::text),
  CONSTRAINT attempts_check CHECK (max_score > 0::numeric AND score <= max_score),
  CONSTRAINT attempts_elapsed_seconds_check CHECK (elapsed_seconds >= 0),
  CONSTRAINT attempts_finish_state_check CHECK (status = 'in_progress'::text AND submitted_at IS NULL AND finished_at IS NULL OR status = 'submitted'::text AND submitted_at IS NOT NULL AND finished_at IS NOT NULL OR status = 'abandoned'::text AND submitted_at IS NULL AND finished_at IS NOT NULL),
  CONSTRAINT attempts_id_version_unique UNIQUE (id, exam_version_id),
  CONSTRAINT attempts_pkey PRIMARY KEY (id),
  CONSTRAINT attempts_result_details_check CHECK (jsonb_typeof(result_details) = 'array'::text),
  CONSTRAINT attempts_score_check CHECK (score >= 0::numeric),
  CONSTRAINT attempts_status_check CHECK (status = ANY (ARRAY['in_progress'::text, 'submitted'::text, 'abandoned'::text]))
);

CREATE TABLE public.audit_logs (
  id bigint NOT NULL,
  actor_id uuid,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id text,
  details jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id)
);

CREATE TABLE public.exam_solutions (
  exam_id uuid NOT NULL,
  solutions jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT exam_solutions_pkey PRIMARY KEY (exam_id),
  CONSTRAINT exam_solutions_solutions_check CHECK (jsonb_typeof(solutions) = 'array'::text)
);

CREATE TABLE public.exam_version_questions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  exam_version_id uuid NOT NULL,
  exam_id uuid NOT NULL,
  question_version_id uuid NOT NULL,
  question_id uuid NOT NULL,
  "position" integer NOT NULL,
  points numeric(8,2) DEFAULT 1 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT evq_id_version_unique UNIQUE (id, exam_version_id),
  CONSTRAINT evq_position_unique UNIQUE (exam_version_id, "position"),
  CONSTRAINT evq_question_unique UNIQUE (exam_version_id, question_version_id),
  CONSTRAINT exam_version_questions_pkey PRIMARY KEY (id),
  CONSTRAINT exam_version_questions_points_check CHECK (points > 0::numeric),
  CONSTRAINT exam_version_questions_position_check CHECK ("position" > 0)
);

CREATE TABLE public.exam_versions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  exam_id uuid NOT NULL,
  version_no integer NOT NULL,
  title text NOT NULL,
  description text DEFAULT ''::text NOT NULL,
  duration_minutes integer NOT NULL,
  status text DEFAULT 'draft'::text NOT NULL,
  created_by uuid,
  published_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  published_at timestamp with time zone,
  CONSTRAINT exam_versions_duration_minutes_check CHECK (duration_minutes >= 1 AND duration_minutes <= 600),
  CONSTRAINT exam_versions_exam_version_unique UNIQUE (exam_id, version_no),
  CONSTRAINT exam_versions_id_exam_unique UNIQUE (id, exam_id),
  CONSTRAINT exam_versions_pkey PRIMARY KEY (id),
  CONSTRAINT exam_versions_publish_state_check CHECK (status = 'draft'::text AND published_at IS NULL OR status = 'published'::text AND published_at IS NOT NULL),
  CONSTRAINT exam_versions_status_check CHECK (status = ANY (ARRAY['draft'::text, 'published'::text])),
  CONSTRAINT exam_versions_title_check CHECK (length(TRIM(BOTH FROM title)) >= 1 AND length(TRIM(BOTH FROM title)) <= 240),
  CONSTRAINT exam_versions_version_no_check CHECK (version_no > 0)
);

CREATE TABLE public.exams (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  title text NOT NULL,
  description text DEFAULT ''::text NOT NULL,
  duration_minutes integer NOT NULL,
  questions_public jsonb DEFAULT '[]'::jsonb NOT NULL,
  is_published boolean DEFAULT false NOT NULL,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT exams_duration_minutes_check CHECK (duration_minutes >= 1 AND duration_minutes <= 600),
  CONSTRAINT exams_pkey PRIMARY KEY (id),
  CONSTRAINT exams_questions_public_check CHECK (jsonb_typeof(questions_public) = 'array'::text),
  CONSTRAINT exams_title_check CHECK (length(TRIM(BOTH FROM title)) >= 1 AND length(TRIM(BOTH FROM title)) <= 240)
);

CREATE TABLE public.profiles (
  id uuid NOT NULL,
  email text NOT NULL,
  role text DEFAULT 'student'::text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  user_code text DEFAULT ('TSA-'::text || lpad((nextval('tsa_user_code_seq'::regclass))::text, 6, '0'::text)) NOT NULL,
  display_name text NOT NULL,
  CONSTRAINT profiles_display_name_check CHECK (char_length(btrim(display_name)) >= 1 AND char_length(btrim(display_name)) <= 80),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_role_check CHECK (role = ANY (ARRAY['admin'::text, 'student'::text])),
  CONSTRAINT profiles_status_check CHECK (status = ANY (ARRAY['active'::text, 'suspended'::text])),
  CONSTRAINT profiles_user_code_format_check CHECK (user_code ~ '^TSA-[0-9]{6}$'::text),
  CONSTRAINT profiles_user_code_key UNIQUE (user_code)
);

CREATE TABLE public.question_answer_keys (
  question_version_id uuid NOT NULL,
  answer_key jsonb NOT NULL,
  explanation text DEFAULT ''::text NOT NULL,
  grading_config jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  source_metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  CONSTRAINT question_answer_keys_grading_config_check CHECK (jsonb_typeof(grading_config) = 'object'::text),
  CONSTRAINT question_answer_keys_metadata_object_check CHECK (jsonb_typeof(source_metadata) = 'object'::text),
  CONSTRAINT question_answer_keys_pkey PRIMARY KEY (question_version_id)
);

CREATE TABLE public.question_versions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  question_id uuid NOT NULL,
  version_no integer NOT NULL,
  question_type text NOT NULL,
  content jsonb NOT NULL,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT question_versions_content_check CHECK (jsonb_typeof(content) = 'object'::text AND content ? 'q'::text),
  CONSTRAINT question_versions_id_question_unique UNIQUE (id, question_id),
  CONSTRAINT question_versions_pkey PRIMARY KEY (id),
  CONSTRAINT question_versions_question_type_check CHECK (question_type = ANY (ARRAY['mc'::text, 'ms'::text, 'tf'::text, 'num'::text, 'dnd'::text])),
  CONSTRAINT question_versions_question_version_unique UNIQUE (question_id, version_no),
  CONSTRAINT question_versions_version_no_check CHECK (version_no > 0)
);

CREATE TABLE public.questions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  scope text NOT NULL,
  owner_exam_id uuid,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT questions_pkey PRIMARY KEY (id),
  CONSTRAINT questions_scope_check CHECK (scope = ANY (ARRAY['bank'::text, 'exam'::text])),
  CONSTRAINT questions_scope_owner_check CHECK (scope = 'bank'::text AND owner_exam_id IS NULL OR scope = 'exam'::text AND owner_exam_id IS NOT NULL)
);

ALTER TABLE public.attempt_answers ADD CONSTRAINT attempt_answers_attempt_fk FOREIGN KEY (attempt_id, exam_version_id) REFERENCES attempts(id, exam_version_id) ON DELETE CASCADE;

ALTER TABLE public.attempt_answers ADD CONSTRAINT attempt_answers_exam_question_fk FOREIGN KEY (exam_version_question_id, exam_version_id) REFERENCES exam_version_questions(id, exam_version_id) ON DELETE RESTRICT;

ALTER TABLE public.attempt_question_times ADD CONSTRAINT attempt_question_times_attempt_fk FOREIGN KEY (attempt_id, exam_version_id) REFERENCES attempts(id, exam_version_id) ON DELETE CASCADE;

ALTER TABLE public.attempt_question_times ADD CONSTRAINT attempt_question_times_exam_question_fk FOREIGN KEY (exam_version_question_id, exam_version_id) REFERENCES exam_version_questions(id, exam_version_id) ON DELETE RESTRICT;

ALTER TABLE public.attempts ADD CONSTRAINT attempts_exam_id_fkey FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE;

ALTER TABLE public.attempts ADD CONSTRAINT attempts_exam_version_fk FOREIGN KEY (exam_version_id, exam_id) REFERENCES exam_versions(id, exam_id) ON DELETE RESTRICT;

ALTER TABLE public.attempts ADD CONSTRAINT attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.audit_logs ADD CONSTRAINT audit_logs_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.exam_solutions ADD CONSTRAINT exam_solutions_exam_id_fkey FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE;

ALTER TABLE public.exam_version_questions ADD CONSTRAINT evq_exam_version_fk FOREIGN KEY (exam_version_id, exam_id) REFERENCES exam_versions(id, exam_id) ON DELETE RESTRICT;

ALTER TABLE public.exam_version_questions ADD CONSTRAINT evq_question_version_fk FOREIGN KEY (question_version_id, question_id) REFERENCES question_versions(id, question_id) ON DELETE RESTRICT;

ALTER TABLE public.exam_versions ADD CONSTRAINT exam_versions_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.exam_versions ADD CONSTRAINT exam_versions_exam_id_fkey FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE RESTRICT;

ALTER TABLE public.exam_versions ADD CONSTRAINT exam_versions_published_by_fkey FOREIGN KEY (published_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.exams ADD CONSTRAINT exams_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.question_answer_keys ADD CONSTRAINT question_answer_keys_question_version_id_fkey FOREIGN KEY (question_version_id) REFERENCES question_versions(id) ON DELETE RESTRICT;

ALTER TABLE public.question_versions ADD CONSTRAINT question_versions_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.question_versions ADD CONSTRAINT question_versions_question_id_fkey FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE RESTRICT;

ALTER TABLE public.questions ADD CONSTRAINT questions_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.questions ADD CONSTRAINT questions_owner_exam_id_fkey FOREIGN KEY (owner_exam_id) REFERENCES exams(id) ON DELETE RESTRICT;

CREATE INDEX attempt_answers_attempt_idx ON public.attempt_answers USING btree (attempt_id);

CREATE INDEX attempt_answers_attempt_version_fk_idx ON public.attempt_answers USING btree (attempt_id, exam_version_id);

CREATE INDEX attempt_answers_question_version_fk_idx ON public.attempt_answers USING btree (exam_version_question_id, exam_version_id);

CREATE INDEX attempt_question_times_attempt_idx ON public.attempt_question_times USING btree (attempt_id);

CREATE INDEX attempt_question_times_attempt_version_fk_idx ON public.attempt_question_times USING btree (attempt_id, exam_version_id);

CREATE INDEX attempt_question_times_question_version_fk_idx ON public.attempt_question_times USING btree (exam_version_question_id, exam_version_id);

CREATE INDEX attempts_exam_submitted_idx ON public.attempts USING btree (exam_id, submitted_at DESC);

CREATE INDEX attempts_exam_version_exam_fk_idx ON public.attempts USING btree (exam_version_id, exam_id);

CREATE UNIQUE INDEX attempts_one_open_per_user_version ON public.attempts USING btree (user_id, exam_version_id) WHERE ((status = 'in_progress'::text) AND (exam_version_id IS NOT NULL));

CREATE INDEX attempts_user_submitted_idx ON public.attempts USING btree (user_id, submitted_at DESC);

CREATE INDEX attempts_version_user_idx ON public.attempts USING btree (exam_version_id, user_id, started_at DESC);

CREATE INDEX audit_logs_actor_id_idx ON public.audit_logs USING btree (actor_id);

CREATE INDEX audit_logs_created_idx ON public.audit_logs USING btree (created_at DESC);

CREATE INDEX evq_exam_version_exam_fk_idx ON public.exam_version_questions USING btree (exam_version_id, exam_id);

CREATE INDEX evq_exam_version_idx ON public.exam_version_questions USING btree (exam_version_id, "position");

CREATE INDEX evq_question_version_idx ON public.exam_version_questions USING btree (question_version_id);

CREATE INDEX evq_question_version_question_fk_idx ON public.exam_version_questions USING btree (question_version_id, question_id);

CREATE INDEX exam_versions_created_by_idx ON public.exam_versions USING btree (created_by);

CREATE INDEX exam_versions_exam_idx ON public.exam_versions USING btree (exam_id, version_no DESC);

CREATE INDEX exam_versions_published_by_idx ON public.exam_versions USING btree (published_by);

CREATE INDEX exam_versions_status_idx ON public.exam_versions USING btree (status, created_at DESC);

CREATE INDEX exams_created_by_idx ON public.exams USING btree (created_by);

CREATE INDEX exams_published_updated_idx ON public.exams USING btree (is_published, updated_at DESC);

CREATE INDEX question_versions_created_by_idx ON public.question_versions USING btree (created_by);

CREATE INDEX question_versions_question_idx ON public.question_versions USING btree (question_id, version_no DESC);

CREATE INDEX questions_created_by_idx ON public.questions USING btree (created_by);

CREATE INDEX questions_owner_exam_idx ON public.questions USING btree (owner_exam_id) WHERE (owner_exam_id IS NOT NULL);

CREATE INDEX questions_scope_idx ON public.questions USING btree (scope, created_at DESC);

CREATE OR REPLACE FUNCTION public.audit_exam_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target uuid;
  action_name text;
  exam_title text;
begin
  if auth.uid() is null then
    if tg_op = 'DELETE' then return old; else return new; end if;
  end if;
  if tg_op = 'DELETE' then
    target := old.id;
    action_name := 'exam.delete';
    exam_title := old.title;
    insert into public.audit_logs(actor_id, action, target_type, target_id, details)
    values (auth.uid(), action_name, 'exam', target::text, jsonb_build_object('title', exam_title));
    return old;
  elsif tg_op = 'INSERT' then
    target := new.id;
    action_name := 'exam.create';
    exam_title := new.title;
  else
    target := new.id;
    action_name := 'exam.update';
    exam_title := new.title;
  end if;
  insert into public.audit_logs(actor_id, action, target_type, target_id, details)
  values (auth.uid(), action_name, 'exam', target::text,
          jsonb_build_object('title', exam_title, 'is_published', new.is_published));
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.audit_profile_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then return new; end if;
  if old.role is distinct from new.role or old.status is distinct from new.status then
    insert into public.audit_logs(actor_id, action, target_type, target_id, details)
    values (auth.uid(), 'user.permission_change', 'profile', new.id::text,
      jsonb_build_object('email', new.email,
                         'old_role', old.role, 'new_role', new.role,
                         'old_status', old.status, 'new_status', new.status));
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_display_name text;
begin
  -- Lấy tên hiển thị từ metadata khi đăng ký
  v_display_name := nullif(
    btrim(new.raw_user_meta_data ->> 'display_name'),
    ''
  );

  -- Kiểm tra tên hiển thị
  if v_display_name is null
     or char_length(v_display_name) > 80 then
    raise exception 'Tên hiển thị phải có từ 1 đến 80 ký tự';
  end if;

  -- Đảm bảo tài khoản có email
  if new.email is null or btrim(new.email) = '' then
    raise exception 'Email đăng ký không hợp lệ';
  end if;

  -- Tạo hồ sơ với quyền mặc định
  insert into public.profiles (
    id,
    email,
    user_code,
    display_name,
    role,
    status
  )
  values (
    new.id,
    new.email,
    default,
    v_display_name,
    'student',
    'active'
  )
  on conflict (id)
  do update set email = excluded.email;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
      and p.status = 'active'
  );
$function$
;

CREATE OR REPLACE FUNCTION public.prevent_answer_key_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
    RAISE EXCEPTION
        'Đáp án của question_version là bất biến. Hãy tạo phiên bản câu hỏi mới.';
END;
$function$
;

CREATE OR REPLACE FUNCTION public.prevent_last_active_admin_removal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  active_admins integer;
begin
  if old.role = 'admin' and old.status = 'active'
     and (new.role <> 'admin' or new.status <> 'active') then
    select count(*) into active_admins
    from public.profiles
    where role = 'admin' and status = 'active' and id <> old.id;
    if active_admins = 0 then
      raise exception 'Không thể vô hiệu hóa hoặc hạ quyền Admin cuối cùng';
    end if;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.prevent_last_admin_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  active_admins integer;
begin
  if old.role = 'admin' and old.status = 'active' then
    select count(*) into active_admins from public.profiles
    where role = 'admin' and status = 'active' and id <> old.id;
    if active_admins = 0 then
      raise exception 'Không thể xóa Admin cuối cùng';
    end if;
  end if;
  return old;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.prevent_question_identity_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
    RAISE EXCEPTION
        'Không được sửa hoặc xóa định danh câu hỏi. Hãy tạo phiên bản mới.';
END;
$function$
;

CREATE OR REPLACE FUNCTION public.prevent_question_version_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
    RAISE EXCEPTION
        'Phiên bản câu hỏi là bất biến. Hãy tạo question_version mới.';
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

CREATE TRIGGER audit_exam_changes AFTER INSERT OR DELETE OR UPDATE ON exams FOR EACH ROW EXECUTE FUNCTION audit_exam_change();

CREATE TRIGGER audit_profile_changes AFTER UPDATE OF role, status ON profiles FOR EACH ROW EXECUTE FUNCTION audit_profile_change();

CREATE TRIGGER on_auth_user_created_profile AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();

CREATE TRIGGER prevent_last_active_admin BEFORE UPDATE OF role, status ON profiles FOR EACH ROW EXECUTE FUNCTION prevent_last_active_admin_removal();

CREATE TRIGGER prevent_last_admin_delete BEFORE DELETE ON profiles FOR EACH ROW EXECUTE FUNCTION prevent_last_admin_delete();

CREATE TRIGGER question_answer_keys_immutable BEFORE DELETE OR UPDATE ON question_answer_keys FOR EACH ROW EXECUTE FUNCTION prevent_answer_key_change();

CREATE TRIGGER question_versions_immutable BEFORE DELETE OR UPDATE ON question_versions FOR EACH ROW EXECUTE FUNCTION prevent_question_version_change();

CREATE TRIGGER questions_identity_immutable BEFORE DELETE OR UPDATE ON questions FOR EACH ROW EXECUTE FUNCTION prevent_question_identity_change();

ALTER TABLE public.attempt_answers ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.attempt_question_times ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.attempts ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.exam_solutions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.exam_version_questions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.exam_versions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.question_answer_keys ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.question_versions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;

CREATE POLICY attempt_answers_read_owner_admin ON public.attempt_answers AS PERMISSIVE FOR SELECT TO authenticated USING (EXISTS ( SELECT 1
   FROM attempts a
  WHERE ((a.id = attempt_answers.attempt_id) AND ((a.user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin)))));

CREATE POLICY attempt_question_times_read_owner_admin ON public.attempt_question_times AS PERMISSIVE FOR SELECT TO authenticated USING (EXISTS ( SELECT 1
   FROM attempts a
  WHERE ((a.id = attempt_question_times.attempt_id) AND ((a.user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin)))));

CREATE POLICY attempts_read_self_or_admin ON public.attempts AS PERMISSIVE FOR SELECT TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin));

CREATE POLICY audit_logs_admin_read ON public.audit_logs AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT is_admin() AS is_admin));

CREATE POLICY exams_read_published_or_admin ON public.exams AS PERMISSIVE FOR SELECT TO authenticated USING ((is_published = true) OR ( SELECT is_admin() AS is_admin));

CREATE POLICY profiles_read_self_or_admin ON public.profiles AS PERMISSIVE FOR SELECT TO authenticated USING ((id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin));

GRANT SELECT ON TABLE public.attempt_answers TO authenticated;

GRANT SELECT ON TABLE public.attempt_question_times TO authenticated;

GRANT SELECT ON TABLE public.attempts TO authenticated;

GRANT SELECT ON TABLE public.audit_logs TO authenticated;

GRANT SELECT ON TABLE public.exams TO authenticated;

GRANT SELECT ON TABLE public.profiles TO authenticated;

GRANT ALL PRIVILEGES ON TABLE public.attempt_answers TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.attempt_question_times TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.attempts TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.audit_logs TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.exam_solutions TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.exam_version_questions TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.exam_versions TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.exams TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.profiles TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.question_answer_keys TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.question_versions TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.questions TO service_role;

-- Reconstructed pre-005 deadline RPCs.
-- pg_stat_statements retained the later patch but not the original function bodies.
-- These definitions are reconstructed from the current live RPCs and reset to the
-- pre-005 exclusive deadline comparison expected by migration 018. They are a
-- compatibility fixture, not a claim of byte-for-byte historical source.
CREATE OR REPLACE FUNCTION public.record_attempt_question_time(p_attempt_id uuid, p_exam_version_question_id uuid, p_seconds integer, p_visit_increment integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_attempt record;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_seconds < 0 OR p_seconds > 300
       OR p_visit_increment NOT IN (0, 1) THEN
        RAISE EXCEPTION 'Giá trị thời gian không hợp lệ.';
    END IF;

    SELECT
        a.user_id,
        a.exam_version_id,
        a.status,
        a.started_at,
        ev.duration_minutes
    INTO v_attempt
    FROM public.attempts a
    JOIN public.exam_versions ev
        ON ev.id = a.exam_version_id
    WHERE a.id = p_attempt_id
    FOR UPDATE OF a;

    IF NOT FOUND
       OR v_attempt.user_id IS DISTINCT FROM v_uid
       OR v_attempt.status <> 'in_progress' THEN
        RAISE EXCEPTION 'Không có quyền ghi thời gian cho lần thi này.';
    END IF;

    IF clock_timestamp() >
       v_attempt.started_at + make_interval(mins => v_attempt.duration_minutes) THEN
        RAISE EXCEPTION 'Đã hết thời gian làm bài.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.exam_version_questions
        WHERE id = p_exam_version_question_id
          AND exam_version_id = v_attempt.exam_version_id
    ) THEN
        RAISE EXCEPTION 'Câu hỏi không thuộc lần thi này.';
    END IF;

    INSERT INTO public.attempt_question_times (
        attempt_id,
        exam_version_id,
        exam_version_question_id,
        seconds_spent,
        visit_count
    )
    VALUES (
        p_attempt_id,
        v_attempt.exam_version_id,
        p_exam_version_question_id,
        p_seconds,
        p_visit_increment
    )
    ON CONFLICT (attempt_id, exam_version_question_id)
    DO UPDATE SET
        seconds_spent = LEAST(
            public.attempt_question_times.seconds_spent
                + EXCLUDED.seconds_spent,
            v_attempt.duration_minutes * 60
        ),
        visit_count = public.attempt_question_times.visit_count
            + EXCLUDED.visit_count,
        updated_at = clock_timestamp();

    UPDATE public.attempts
    SET last_activity_at = clock_timestamp()
    WHERE id = p_attempt_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.save_attempt_answer(p_attempt_id uuid, p_exam_version_question_id uuid, p_answer jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_attempt record;
    v_question_type text;
    v_content jsonb;
    v_option_count integer;
    v_slot_count integer;
    v_distinct_slot_count integer;
    v_count integer;
    v_distinct_count integer;
    v_valid boolean;
    v_number numeric;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT
        a.user_id,
        a.exam_version_id,
        a.status,
        a.started_at,
        ev.duration_minutes
    INTO v_attempt
    FROM public.attempts a
    JOIN public.exam_versions ev
        ON ev.id = a.exam_version_id
    WHERE a.id = p_attempt_id
    FOR UPDATE OF a;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy lần làm bài.';
    END IF;

    IF v_attempt.user_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'Không có quyền sửa lần làm bài này.';
    END IF;

    IF v_attempt.status <> 'in_progress' THEN
        RAISE EXCEPTION 'Lần làm bài đã kết thúc.';
    END IF;

    IF clock_timestamp() >
       v_attempt.started_at + make_interval(mins => v_attempt.duration_minutes) THEN
        RAISE EXCEPTION 'Đã hết thời gian làm bài.';
    END IF;

    SELECT qv.question_type, qv.content
    INTO v_question_type, v_content
    FROM public.exam_version_questions evq
    JOIN public.question_versions qv
        ON qv.id = evq.question_version_id
    WHERE evq.id = p_exam_version_question_id
      AND evq.exam_version_id = v_attempt.exam_version_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Câu hỏi không thuộc phiên bản đề này.';
    END IF;

    -- JSON null means clear the current answer.
    IF p_answer IS NULL OR p_answer = 'null'::jsonb THEN
        DELETE FROM public.attempt_answers
        WHERE attempt_id = p_attempt_id
          AND exam_version_question_id = p_exam_version_question_id;

        UPDATE public.attempts
        SET last_activity_at = clock_timestamp()
        WHERE id = p_attempt_id;

        RETURN;
    END IF;

    v_option_count := jsonb_array_length(v_content->'o');

    CASE v_question_type

        WHEN 'mc' THEN
            IF jsonb_typeof(p_answer) <> 'number' THEN
                RAISE EXCEPTION 'MC cần một chỉ số phương án.';
            END IF;

            v_number := (p_answer #>> '{}')::numeric;

            IF v_number <> trunc(v_number)
               OR v_number < 0
               OR v_number >= v_option_count THEN
                RAISE EXCEPTION 'Chỉ số phương án MC không hợp lệ.';
            END IF;

        WHEN 'ms' THEN
            IF jsonb_typeof(p_answer) <> 'array' THEN
                RAISE EXCEPTION 'MS cần một mảng phương án.';
            END IF;

            SELECT
                count(*),
                count(DISTINCT CASE
                    WHEN value ~ '^[0-9]+$'
                    THEN value::integer
                END),
                COALESCE(bool_and(
                    CASE
                        WHEN value ~ '^[0-9]+$'
                        THEN value::integer BETWEEN 0 AND v_option_count - 1
                        ELSE false
                    END
                ), true)
            INTO v_count, v_distinct_count, v_valid
            FROM jsonb_array_elements_text(p_answer) AS x(value);

            IF NOT v_valid OR v_count <> v_distinct_count THEN
                RAISE EXCEPTION 'Danh sách phương án MS không hợp lệ.';
            END IF;

        WHEN 'tf' THEN
            IF jsonb_typeof(p_answer) <> 'array'
               OR jsonb_array_length(p_answer) <> v_option_count
               OR EXISTS (
                    SELECT 1
                    FROM jsonb_array_elements(p_answer) AS x(value)
                    WHERE value NOT IN (
                        'true'::jsonb,
                        'false'::jsonb,
                        'null'::jsonb
                    )
               ) THEN
                RAISE EXCEPTION 'Mảng trả lời TF không hợp lệ.';
            END IF;

        WHEN 'num' THEN
            IF jsonb_typeof(p_answer) <> 'number' THEN
                RAISE EXCEPTION 'NUM cần một giá trị số.';
            END IF;

        WHEN 'dnd' THEN
            IF jsonb_typeof(p_answer) <> 'array' THEN
                RAISE EXCEPTION 'DND cần một mảng ghép nối.';
            END IF;

            SELECT
                COALESCE(MAX((m)[1]::integer), 0),
                count(DISTINCT (m)[1]::integer)
            INTO v_slot_count, v_distinct_slot_count
            FROM regexp_matches(
                v_content->>'q',
                '\[([0-9]+)\]',
                'g'
            ) AS x(m);

            IF v_slot_count = 0
               OR v_slot_count <> v_distinct_slot_count
               OR jsonb_array_length(p_answer) <> v_slot_count THEN
                RAISE EXCEPTION 'Cấu trúc vị trí ghép nối không hợp lệ.';
            END IF;

            SELECT
                count(*),
                count(DISTINCT CASE
                    WHEN value ~ '^[0-9]+$'
                    THEN value::integer
                END),
                COALESCE(bool_and(
                    CASE
                        WHEN value ~ '^[0-9]+$'
                        THEN value::integer BETWEEN 0 AND v_option_count - 1
                        ELSE false
                    END
                ), true)
            INTO v_count, v_distinct_count, v_valid
            FROM jsonb_array_elements_text(p_answer) AS x(value)
            WHERE value IS NOT NULL;

            IF NOT v_valid OR v_count <> v_distinct_count THEN
                RAISE EXCEPTION
                    'Ghép nối không hợp lệ: mỗi phương án chỉ được sử dụng một lần.';
            END IF;

        ELSE
            RAISE EXCEPTION 'Loại câu hỏi chưa được hỗ trợ.';
    END CASE;

    INSERT INTO public.attempt_answers (
        attempt_id,
        exam_version_id,
        exam_version_question_id,
        answer
    )
    VALUES (
        p_attempt_id,
        v_attempt.exam_version_id,
        p_exam_version_question_id,
        p_answer
    )
    ON CONFLICT (attempt_id, exam_version_question_id)
    DO UPDATE SET
        answer = EXCLUDED.answer,
        updated_at = clock_timestamp(),
        is_correct = NULL,
        earned_points = NULL,
        graded_at = NULL;

    UPDATE public.attempts
    SET last_activity_at = clock_timestamp()
    WHERE id = p_attempt_id;
END;
$function$;

-- Reconstructed pre-005 start_exam_attempt RPC.
-- The original function body is not retained in the migration ledger. This copy
-- is reconstructed from the live function, with the post-020 archive predicate
-- removed so migration 020 can exercise its intended transformation.
CREATE OR REPLACE FUNCTION public.start_exam_attempt(p_exam_version_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_exam_id uuid;
    v_duration integer;
    v_question_count integer;
    v_missing_keys integer;
    v_max_score numeric;
    v_attempt_id uuid;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = v_uid
          AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Tài khoản không hoạt động.';
    END IF;

    SELECT exam_id, duration_minutes
    INTO v_exam_id, v_duration
    FROM public.exam_versions
    WHERE id = p_exam_version_id
      AND status = 'published';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Đề thi không tồn tại hoặc chưa xuất bản.';
    END IF;

    SELECT
        count(*),
        COALESCE(sum(evq.points), 0),
        count(*) FILTER (
            WHERE ak.question_version_id IS NULL
        )
    INTO
        v_question_count,
        v_max_score,
        v_missing_keys
    FROM public.exam_version_questions evq
    LEFT JOIN public.question_answer_keys ak
        ON ak.question_version_id = evq.question_version_id
    WHERE evq.exam_version_id = p_exam_version_id;

    IF v_question_count = 0 OR v_max_score <= 0 THEN
        RAISE EXCEPTION 'Đề thi chưa có câu hỏi hợp lệ.';
    END IF;

    IF v_missing_keys > 0 THEN
        RAISE EXCEPTION
            'Đề thi còn % câu chưa có đáp án.',
            v_missing_keys;
    END IF;

    INSERT INTO public.attempts (
        user_id,
        exam_id,
        exam_version_id,
        answers,
        score,
        max_score,
        elapsed_seconds,
        result_details,
        status,
        started_at,
        last_activity_at
    )
    VALUES (
        v_uid,
        v_exam_id,
        p_exam_version_id,
        '[]'::jsonb,
        0,
        v_max_score,
        0,
        '[]'::jsonb,
        'in_progress',
        clock_timestamp(),
        clock_timestamp()
    )
    ON CONFLICT (user_id, exam_version_id)
    WHERE status = 'in_progress'
      AND exam_version_id IS NOT NULL
    DO NOTHING
    RETURNING id INTO v_attempt_id;

    -- A concurrent start may have created the open attempt first.
    IF v_attempt_id IS NULL THEN
        SELECT id
        INTO v_attempt_id
        FROM public.attempts
        WHERE user_id = v_uid
          AND exam_version_id = p_exam_version_id
          AND status = 'in_progress'
        LIMIT 1;
    END IF;

    RETURN v_attempt_id;
END;
$function$;

-- Reconstructed pre-005 attempt and exam integrity triggers.
-- These live integrity objects predate the recovered 005-020 migration ledger
-- but were absent from its SQL statements. Reconstructed from the live catalog.
CREATE OR REPLACE FUNCTION public.guard_attempt_child()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_attempt_id uuid;
  v_status text;
  v_user_id uuid;
begin
  if tg_op = 'DELETE' then
    v_attempt_id := old.attempt_id;
  else
    v_attempt_id := new.attempt_id;
  end if;

  if tg_op = 'UPDATE' then
    if new.attempt_id is distinct from old.attempt_id
       or new.exam_version_id is distinct from old.exam_version_id
       or new.exam_version_question_id is distinct from old.exam_version_question_id then
      raise exception 'Không được chuyển câu trả lời sang lần thi hoặc câu hỏi khác.';
    end if;
  end if;

  select a.user_id,a.status
  into v_user_id,v_status
  from public.attempts a
  where a.id=v_attempt_id;

  if not found
     or v_status<>'in_progress'
     or auth.uid() is null
     or v_user_id is distinct from auth.uid()
     or not exists (
       select 1 from public.profiles p
       where p.id=auth.uid() and p.status='active'
     ) then
    raise exception 'Chỉ chủ tài khoản đang hoạt động mới được sửa dữ liệu của lần làm bài đang diễn ra.';
  end if;

  if tg_op='DELETE' then return old; end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.guard_attempt_record()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  if tg_op='DELETE' then
    raise exception 'Không được xóa lịch sử làm bài.';
  end if;

  if old.status<>'in_progress' then
    raise exception 'Lần làm bài đã kết thúc và không thể chỉnh sửa.';
  end if;

  if new.id is distinct from old.id
     or new.user_id is distinct from old.user_id
     or new.exam_id is distinct from old.exam_id
     or new.exam_version_id is distinct from old.exam_version_id
     or new.started_at is distinct from old.started_at
     or new.max_score is distinct from old.max_score then
    raise exception 'Không được thay đổi định danh hoặc chủ sở hữu lần làm bài.';
  end if;

  if auth.uid() is null
     or old.user_id is distinct from auth.uid()
     or not exists (
       select 1 from public.profiles p
       where p.id=auth.uid() and p.status='active'
     ) then
    raise exception 'Chỉ chủ tài khoản đang hoạt động mới được cập nhật lần làm bài.';
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.protect_exam_version()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF current_setting('app.allow_exam_version_delete', true) IS DISTINCT FROM 'on' THEN
      RAISE EXCEPTION 'Chỉ được xóa phiên bản đề qua thao tác quản trị có kiểm tra.';
    END IF;
    IF EXISTS (SELECT 1 FROM public.attempts a WHERE a.exam_version_id = OLD.id) THEN
      RAISE EXCEPTION 'Không thể xóa phiên bản đã có lượt làm bài; cần giữ lại lịch sử kết quả.';
    END IF;
    RETURN OLD;
  END IF;

  IF OLD.status <> 'draft' THEN
    IF current_setting('app.allow_exam_version_delete', true) = 'on'
       AND OLD.status = 'published'
       AND NEW.archived_at IS DISTINCT FROM OLD.archived_at
       AND (to_jsonb(NEW) - 'archived_at') = (to_jsonb(OLD) - 'archived_at') THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Phiên bản đã xuất bản không thể chỉnh sửa. Hãy tạo phiên bản mới.';
  END IF;

  IF NEW.exam_id IS DISTINCT FROM OLD.exam_id
     OR NEW.version_no IS DISTINCT FROM OLD.version_no
     OR NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Không được thay đổi định danh hoặc số phiên bản đề thi.';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.protect_exam_version_questions()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_status text;
  v_exam_id uuid;
  v_scope text;
  v_owner_exam_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    SELECT status INTO v_status
      FROM public.exam_versions
     WHERE id = OLD.exam_version_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Không tìm thấy exam_version.';
    END IF;
    IF current_setting('app.allow_exam_version_delete', true) = 'on' THEN
      RETURN OLD;
    END IF;
    IF v_status <> 'draft' THEN
      RAISE EXCEPTION 'Không được thay đổi danh sách câu hỏi của đề đã xuất bản.';
    END IF;
    RETURN OLD;
  END IF;

  SELECT status, exam_id INTO v_status, v_exam_id
    FROM public.exam_versions WHERE id = NEW.exam_version_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Không tìm thấy exam_version.'; END IF;
  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Không được thay đổi danh sách câu hỏi của đề đã xuất bản.';
  END IF;
  IF NEW.exam_id IS DISTINCT FROM v_exam_id THEN
    RAISE EXCEPTION 'exam_id không khớp với exam_version.';
  END IF;
  SELECT scope, owner_exam_id INTO v_scope, v_owner_exam_id
    FROM public.questions WHERE id = NEW.question_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Không tìm thấy câu hỏi.'; END IF;
  IF v_scope = 'exam' AND v_owner_exam_id IS DISTINCT FROM v_exam_id THEN
    RAISE EXCEPTION 'Câu hỏi riêng của đề khác không được sử dụng ở đề này.';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER attempts_guard_update BEFORE DELETE OR UPDATE ON public.attempts FOR EACH ROW EXECUTE FUNCTION public.guard_attempt_record();
CREATE TRIGGER attempt_answers_guard BEFORE INSERT OR DELETE OR UPDATE ON public.attempt_answers FOR EACH ROW EXECUTE FUNCTION public.guard_attempt_child();
CREATE TRIGGER exam_versions_immutable_after_publish BEFORE DELETE OR UPDATE ON public.exam_versions FOR EACH ROW EXECUTE FUNCTION public.protect_exam_version();
CREATE TRIGGER exam_version_questions_protected BEFORE INSERT OR DELETE OR UPDATE ON public.exam_version_questions FOR EACH ROW EXECUTE FUNCTION public.protect_exam_version_questions();
