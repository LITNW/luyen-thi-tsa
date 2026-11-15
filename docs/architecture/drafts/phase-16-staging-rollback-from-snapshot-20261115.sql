BEGIN;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON SEQUENCES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin REVOKE ALL ON SEQUENCES FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON SEQUENCE public.audit_logs_id_seq FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON SEQUENCE public.import_events_id_seq FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON SEQUENCE public.tsa_user_code_seq FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.attempt_answers FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.attempt_question_times FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.attempts FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.audit_logs FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.exam_solutions FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.exam_version_questions FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.exam_versions FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.exams FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.profiles FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.question_answer_keys FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.question_versions FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.questions FROM anon, authenticated;

REVOKE UPDATE (display_name) ON TABLE public.profiles FROM anon, authenticated;

SET ROLE postgres;
GRANT DELETE ON TABLE public.attempt_answers TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.attempt_answers TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.attempt_question_times TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.attempt_question_times TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.attempts TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.attempts TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.audit_logs TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.audit_logs TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.exam_solutions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.exam_solutions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.exam_version_questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.exam_version_questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.exam_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.exam_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.exams TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.exams TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.profiles TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.profiles TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.question_answer_keys TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.question_answer_keys TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.question_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.question_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT DELETE ON TABLE public.questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.attempt_answers TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.attempt_answers TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.attempt_question_times TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.attempt_question_times TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.attempts TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.attempts TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.audit_logs TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.audit_logs TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.exam_solutions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.exam_solutions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.exam_version_questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.exam_version_questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.exam_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.exam_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.exams TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.exams TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.profiles TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.profiles TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.question_answer_keys TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.question_answer_keys TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.question_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.question_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT INSERT ON TABLE public.questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.attempt_answers TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.attempt_answers TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.attempt_question_times TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.attempt_question_times TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.attempts TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.attempts TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.audit_logs TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.audit_logs TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.exam_solutions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.exam_solutions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.exam_version_questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.exam_version_questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.exam_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.exam_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.exams TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.exams TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.profiles TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.profiles TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.question_answer_keys TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.question_answer_keys TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.question_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.question_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT MAINTAIN ON TABLE public.questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.attempt_answers TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.attempt_answers TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.attempt_question_times TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.attempt_question_times TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.attempts TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.attempts TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.audit_logs TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.audit_logs TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.exam_solutions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.exam_solutions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.exam_version_questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.exam_version_questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.exam_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.exam_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.exams TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.exams TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.profiles TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.profiles TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.question_answer_keys TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.question_answer_keys TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.question_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.question_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT REFERENCES ON TABLE public.questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.attempt_answers TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.attempt_answers TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.attempt_question_times TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.attempt_question_times TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.attempts TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.attempts TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.audit_logs TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.audit_logs TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.exam_solutions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.exam_solutions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.exam_version_questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.exam_version_questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.exam_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.exam_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.exams TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.exams TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.profiles TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.profiles TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.question_answer_keys TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.question_answer_keys TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.question_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.question_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON TABLE public.questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.attempt_answers TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.attempt_answers TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.attempt_question_times TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.attempt_question_times TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.attempts TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.attempts TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.audit_logs TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.audit_logs TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.exam_solutions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.exam_solutions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.exam_version_questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.exam_version_questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.exam_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.exam_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.exams TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.exams TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.profiles TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.profiles TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.question_answer_keys TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.question_answer_keys TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.question_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.question_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRIGGER ON TABLE public.questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.attempt_answers TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.attempt_answers TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.attempt_question_times TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.attempt_question_times TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.attempts TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.attempts TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.audit_logs TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.audit_logs TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.exam_solutions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.exam_solutions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.exam_version_questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.exam_version_questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.exam_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.exam_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.exams TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.exams TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.profiles TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.profiles TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.question_answer_keys TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.question_answer_keys TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.question_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.question_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT TRUNCATE ON TABLE public.questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.attempt_answers TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.attempt_answers TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.attempt_question_times TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.attempt_question_times TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.attempts TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.attempts TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.audit_logs TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.audit_logs TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.exam_solutions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.exam_solutions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.exam_version_questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.exam_version_questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.exam_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.exam_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.exams TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.exams TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.profiles TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.profiles TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.question_answer_keys TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.question_answer_keys TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.question_versions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.question_versions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.questions TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON TABLE public.questions TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE (display_name) ON TABLE public.profiles TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON SEQUENCE public.audit_logs_id_seq TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON SEQUENCE public.audit_logs_id_seq TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON SEQUENCE public.import_events_id_seq TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON SEQUENCE public.import_events_id_seq TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON SEQUENCE public.tsa_user_code_seq TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT SELECT ON SEQUENCE public.tsa_user_code_seq TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON SEQUENCE public.audit_logs_id_seq TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON SEQUENCE public.audit_logs_id_seq TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON SEQUENCE public.import_events_id_seq TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON SEQUENCE public.import_events_id_seq TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON SEQUENCE public.tsa_user_code_seq TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT UPDATE ON SEQUENCE public.tsa_user_code_seq TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT USAGE ON SEQUENCE public.audit_logs_id_seq TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT USAGE ON SEQUENCE public.audit_logs_id_seq TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT USAGE ON SEQUENCE public.import_events_id_seq TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT USAGE ON SEQUENCE public.import_events_id_seq TO authenticated;\nRESET ROLE;

SET ROLE postgres;
GRANT USAGE ON SEQUENCE public.tsa_user_code_seq TO anon;\nRESET ROLE;

SET ROLE postgres;
GRANT USAGE ON SEQUENCE public.tsa_user_code_seq TO authenticated;\nRESET ROLE;

SET ROLE postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON SEQUENCES TO anon;\nRESET ROLE;

SET ROLE postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON SEQUENCES TO authenticated;\nRESET ROLE;

SET ROLE postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT UPDATE ON SEQUENCES TO anon;\nRESET ROLE;

SET ROLE postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT UPDATE ON SEQUENCES TO authenticated;\nRESET ROLE;

SET ROLE postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT USAGE ON SEQUENCES TO anon;\nRESET ROLE;

SET ROLE postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT USAGE ON SEQUENCES TO authenticated;\nRESET ROLE;

SET ROLE supabase_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT ON SEQUENCES TO anon;\nRESET ROLE;

SET ROLE supabase_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT ON SEQUENCES TO authenticated;\nRESET ROLE;

SET ROLE supabase_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT UPDATE ON SEQUENCES TO anon;\nRESET ROLE;

SET ROLE supabase_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT UPDATE ON SEQUENCES TO authenticated;\nRESET ROLE;

SET ROLE supabase_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT USAGE ON SEQUENCES TO anon;\nRESET ROLE;

SET ROLE supabase_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT USAGE ON SEQUENCES TO authenticated;\nRESET ROLE;

-- Verify restored ACLs against original snapshot. COMMIT only after exact review.
