-- Legacy flat exam RPC contract regression.
-- Run only in the disposable Supabase local stack created by CI.
-- This test protects the current flat editor/runtime while v2 is designed.

begin;

DO $tests$
DECLARE
  v_admin uuid := '00000000-0000-4000-8000-000000000001';
  v_exam_id uuid := '50000000-0000-4000-8000-000000000001';
  v_exam_version_id uuid := '50000000-0000-4000-8000-000000000002';
  v_first_mapping uuid;
  v_second_mapping uuid;
  v_first_question uuid;
  v_second_question uuid;
  v_first_question_version uuid;
  v_clone_id uuid;
  v_clone_mapping uuid;
  v_attempt_id uuid;
  v_save_result jsonb;
  v_admin_payload jsonb;
  v_public_payload jsonb;
  v_submit_result jsonb;
  v_submit_retry jsonb;
  v_attempt_state jsonb;
  v_offering uuid;
BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_admin::text,true);

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id=v_admin AND role='admin' AND status='active'
  ) THEN
    RAISE EXCEPTION 'Legacy contract regression requires the seeded active CI admin.';
  END IF;

  INSERT INTO public.exams(id,title,description,duration_minutes)
  VALUES (v_exam_id,'Legacy contract regression','Disposable CI fixture',30);
  if to_regclass('public.education_subjects') is not null then
    select es.id into v_offering
    from public.education_subjects es
    join public.education_levels l on l.id=es.education_level_id
    join public.subjects s on s.id=es.subject_id
    where l.code='thpt' and es.education_node_id is null and s.code='mathematics'
    limit 1;
    if v_offering is null then
      insert into public.education_subjects(education_level_id,education_node_id,subject_id,display_name)
      select l.id,null,s.id,'CI Mathematics'
      from public.education_levels l
      cross join public.subjects s
      where l.code='thpt' and s.code='mathematics'
      returning id into v_offering;
    end if;
    if v_offering is null then
      raise exception 'CI Mathematics education offering could not be prepared.';
    end if;
    perform public.admin_set_exam_education_subject(v_exam_id,v_offering);
  end if;

  INSERT INTO public.exam_versions(
    id,exam_id,version_no,title,description,duration_minutes,status
  ) VALUES (
    v_exam_version_id,v_exam_id,1,'Legacy contract regression','Disposable CI fixture',30,'draft'
  );

  -- Create two questions through the same flat save RPC used by the legacy editor.
  v_save_result := public.admin_save_exam_content(
    v_exam_version_id,
    'Legacy contract regression',
    'Disposable CI fixture',
    30,
    jsonb_build_array(
      jsonb_build_object(
        'scope','bank',
        'type','mc',
        'content',jsonb_build_object('q','First question?','o',jsonb_build_array('A','B')),
        'answer_key',1,
        'explanation','First explanation',
        'grading_config','{}'::jsonb,
        'source_metadata','{}'::jsonb,
        'points',1
      ),
      jsonb_build_object(
        'scope','bank',
        'type','mc',
        'content',jsonb_build_object('q','Second question?','o',jsonb_build_array('A','B')),
        'answer_key',0,
        'explanation','Second explanation',
        'grading_config','{}'::jsonb,
        'source_metadata','{}'::jsonb,
        'points',2
      )
    ),
    false
  );

  IF v_save_result->>'success' IS DISTINCT FROM 'true'
     OR (v_save_result->>'question_count')::integer <> 2 THEN
    RAISE EXCEPTION 'Legacy flat save did not create the expected two questions: %',v_save_result;
  END IF;

  SELECT id,question_id,question_version_id
    INTO v_first_mapping,v_first_question,v_first_question_version
  FROM public.exam_version_questions
  WHERE exam_version_id=v_exam_version_id AND position=1;

  SELECT id,question_id
    INTO v_second_mapping,v_second_question
  FROM public.exam_version_questions
  WHERE exam_version_id=v_exam_version_id AND position=2;

  IF v_first_mapping IS NULL OR v_second_mapping IS NULL
     OR v_first_question IS NULL OR v_second_question IS NULL THEN
    RAISE EXCEPTION 'Legacy save did not create stable mapping/question identities.';
  END IF;

  -- Re-save the unchanged first question and remove the second one.
  -- The first mapping ID must be retained; the omitted second mapping is intentionally removed.
  v_save_result := public.admin_save_exam_content(
    v_exam_version_id,
    'Legacy contract regression',
    'Disposable CI fixture',
    30,
    jsonb_build_array(
      jsonb_build_object(
        'mapping_id',v_first_mapping,
        'question_id',v_first_question,
        'scope','bank',
        'type','mc',
        'content',jsonb_build_object('q','First question?','o',jsonb_build_array('A','B')),
        'answer_key',1,
        'explanation','First explanation',
        'grading_config','{}'::jsonb,
        'source_metadata','{}'::jsonb,
        'points',1
      )
    ),
    false
  );

  IF v_save_result->>'success' IS DISTINCT FROM 'true'
     OR (v_save_result->>'removed_question_count')::integer <> 1 THEN
    RAISE EXCEPTION 'Legacy reconciliation did not report the expected removal: %',v_save_result;
  END IF;

  IF (SELECT count(*) FROM public.exam_version_questions WHERE exam_version_id=v_exam_version_id) <> 1
     OR NOT EXISTS (
       SELECT 1 FROM public.exam_version_questions
       WHERE id=v_first_mapping
         AND exam_version_id=v_exam_version_id
         AND question_version_id=v_first_question_version
     )
     OR EXISTS (
       SELECT 1 FROM public.exam_version_questions
       WHERE id=v_second_mapping AND exam_version_id=v_exam_version_id
     ) THEN
    RAISE EXCEPTION 'Legacy save changed the retained mapping ID or failed to remove the omitted mapping.';
  END IF;

  -- Admin authoring read must contain answer keys; student-facing read must not.
  v_admin_payload := public.admin_get_exam_version(v_exam_version_id);
  IF jsonb_array_length(v_admin_payload->'questions') <> 1
     OR NOT ((v_admin_payload->'questions'->0) ? 'answer_key')
     OR (v_admin_payload->'questions'->0->>'mapping_id') IS DISTINCT FROM v_first_mapping::text THEN
    RAISE EXCEPTION 'Admin flat read contract changed unexpectedly: %',v_admin_payload;
  END IF;

  -- Publish using the existing authoritative publication RPC.
  v_save_result := public.admin_publish_exam_version(v_exam_version_id);
  IF v_save_result->>'success' IS DISTINCT FROM 'true'
     OR (SELECT status FROM public.exam_versions WHERE id=v_exam_version_id) <> 'published' THEN
    RAISE EXCEPTION 'Valid legacy draft did not publish.';
  END IF;

  v_public_payload := public.get_published_exam(v_exam_version_id);
  IF jsonb_array_length(v_public_payload->'questions') <> 1
     OR (v_public_payload->'questions'->0->>'id') IS DISTINCT FROM v_first_mapping::text
     OR EXISTS (
       SELECT 1
       FROM jsonb_array_elements(v_public_payload->'questions') AS q(value)
       WHERE value ?| ARRAY['answer_key','explanation','grading_config','source_metadata']
     ) THEN
    RAISE EXCEPTION 'Student-facing flat exam payload changed or leaked grading data: %',v_public_payload;
  END IF;

  -- A v1 clone must create new mapping IDs while reusing immutable question versions.
  v_clone_id := public.admin_create_exam_version(v_exam_id);
  SELECT id INTO v_clone_mapping
  FROM public.exam_version_questions
  WHERE exam_version_id=v_clone_id AND position=1;

  IF v_clone_id IS NULL OR v_clone_mapping IS NULL
     OR v_clone_mapping = v_first_mapping
     OR NOT EXISTS (
       SELECT 1 FROM public.exam_version_questions
       WHERE id=v_clone_mapping
         AND exam_version_id=v_clone_id
         AND question_version_id=v_first_question_version
         AND points=1
     ) THEN
    RAISE EXCEPTION 'Legacy exam-version clone did not preserve question content with a new mapping ID.';
  END IF;

  -- Draft clone deletion must remove only the disposable clone.
  v_save_result := public.admin_delete_exam_version(v_clone_id);
  IF v_save_result->>'deleted' IS DISTINCT FROM 'true'
     OR EXISTS (SELECT 1 FROM public.exam_versions WHERE id=v_clone_id) THEN
    RAISE EXCEPTION 'Draft clone was not safely deleted: %',v_save_result;
  END IF;

  -- Existing attempt flow must continue to use the retained mapping ID.
  v_attempt_id := public.start_exam_attempt(v_exam_version_id);
  PERFORM public.save_attempt_answer(v_attempt_id,v_first_mapping,'1'::jsonb);
  v_submit_result := public.submit_exam_attempt(v_attempt_id);

  IF v_submit_result->>'status' IS DISTINCT FROM 'submitted'
     OR (v_submit_result->>'score')::numeric <> 1
     OR (v_submit_result->>'max_score')::numeric <> 1 THEN
    RAISE EXCEPTION 'Legacy attempt grading changed unexpectedly: %',v_submit_result;
  END IF;

  v_submit_retry := public.submit_exam_attempt(v_attempt_id);
  IF v_submit_retry->>'status' IS DISTINCT FROM 'submitted'
     OR (v_submit_retry->>'score')::numeric <> 1
     OR (v_submit_retry->>'max_score')::numeric <> 1 THEN
    RAISE EXCEPTION 'Legacy submission idempotency changed unexpectedly: %',v_submit_retry;
  END IF;

  v_attempt_state := public.get_my_attempt_state(v_attempt_id);
  IF v_attempt_state->>'status' IS DISTINCT FROM 'submitted'
     OR jsonb_typeof(v_attempt_state->'result_details') <> 'array' THEN
    RAISE EXCEPTION 'Legacy attempt state/result contract changed unexpectedly: %',v_attempt_state;
  END IF;
END;
$tests$;

rollback;
