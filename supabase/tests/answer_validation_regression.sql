-- Regression tests for 20261112170000_centralize_exam_answer_validation.sql.
-- Run only in the disposable PostgreSQL database created by the CI workflow.

DO $tests$
DECLARE
  v_saved_version uuid;
  v_question_id uuid;
  v_version_id uuid;
  v_exam_id uuid;
  v_rejected boolean;
  v_result jsonb;
BEGIN
  PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);

  -- Verify RPC grants match the existing Supabase contract and the helper stays private.
  IF has_function_privilege('anon','public.admin_save_question(uuid,text,uuid,text,jsonb,jsonb,text,jsonb,jsonb)','EXECUTE')
     OR has_function_privilege('anon','public.admin_set_question_answer_key(uuid,jsonb,text,jsonb,jsonb)','EXECUTE')
     OR has_function_privilege('anon','public.admin_publish_exam_version(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous role unexpectedly has access to an admin RPC.';
  END IF;
  IF NOT has_function_privilege('authenticated','public.admin_save_question(uuid,text,uuid,text,jsonb,jsonb,text,jsonb,jsonb)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.admin_set_question_answer_key(uuid,jsonb,text,jsonb,jsonb)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.admin_publish_exam_version(uuid)','EXECUTE')
     OR NOT has_function_privilege('service_role','public.admin_save_question(uuid,text,uuid,text,jsonb,jsonb,text,jsonb,jsonb)','EXECUTE')
     OR NOT has_function_privilege('service_role','public.admin_set_question_answer_key(uuid,jsonb,text,jsonb,jsonb)','EXECUTE')
     OR NOT has_function_privilege('service_role','public.admin_publish_exam_version(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'Expected Supabase RPC grants are missing.';
  END IF;
  IF has_function_privilege('authenticated','public.validate_question_answer_key(text,jsonb,jsonb)','EXECUTE')
     OR has_function_privilege('anon','public.validate_question_answer_key(text,jsonb,jsonb)','EXECUTE') THEN
    RAISE EXCEPTION 'Internal answer validator must not be directly executable by API roles.';
  END IF;

  -- Verify all server-side paths use the same validator.
  IF position('public.validate_question_answer_key(' IN pg_get_functiondef(
       'public.admin_save_question(uuid,text,uuid,text,jsonb,jsonb,text,jsonb,jsonb)'::regprocedure
     )) = 0
     OR position('public.validate_question_answer_key(' IN pg_get_functiondef(
       'public.admin_set_question_answer_key(uuid,jsonb,text,jsonb,jsonb)'::regprocedure
     )) = 0
     OR position('public.validate_question_answer_key(' IN pg_get_functiondef(
       'public.admin_publish_exam_version(uuid)'::regprocedure
     )) = 0 THEN
    RAISE EXCEPTION 'One or more RPCs are missing the shared validator.';
  END IF;

  -- Valid answer-key structures for all five question types.
  PERFORM public.validate_question_answer_key(
    'mc','{"q":"Question?","o":["A","B","C","D"]}'::jsonb,'1'::jsonb
  );
  PERFORM public.validate_question_answer_key(
    'ms','{"q":"Question?","o":["A","B","C","D"]}'::jsonb,'[0,2]'::jsonb
  );
  PERFORM public.validate_question_answer_key(
    'tf','{"q":"Question?","o":["a","b","c","d"]}'::jsonb,'[true,false,true,false]'::jsonb
  );
  PERFORM public.validate_question_answer_key(
    'num','{"q":"Question?","o":[]}'::jsonb,'12.5'::jsonb
  );
  PERFORM public.validate_question_answer_key(
    'dnd','{"q":"Câu ghép [1] và [2]","o":["A","B","C","D"]}'::jsonb,'{"1":4,"2":1}'::jsonb
  );

  -- Invalid examples must raise SQLSTATE 22023.
  BEGIN
    PERFORM public.validate_question_answer_key(
      'mc','{"q":"Question?","o":["A","B"]}'::jsonb,'2'::jsonb
    );
    RAISE EXCEPTION 'Invalid MC answer was accepted.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  BEGIN
    PERFORM public.validate_question_answer_key(
      'ms','{"q":"Question?","o":["A","B","C"]}'::jsonb,'[1,1]'::jsonb
    );
    RAISE EXCEPTION 'Duplicate MS answer was accepted.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  BEGIN
    PERFORM public.validate_question_answer_key(
      'tf','{"q":"Question?","o":["a","b"]}'::jsonb,'[true]'::jsonb
    );
    RAISE EXCEPTION 'Incomplete TF answer was accepted.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  BEGIN
    PERFORM public.validate_question_answer_key(
      'num','{"q":"Question?","o":[]}'::jsonb,'"12.5"'::jsonb
    );
    RAISE EXCEPTION 'String NUM answer was accepted.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  BEGIN
    PERFORM public.validate_question_answer_key(
      'dnd','{"q":"[1] and [2]","o":["A","B"]}'::jsonb,'{"1":1,"2":1}'::jsonb
    );
    RAISE EXCEPTION 'Reused DND option was accepted.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  BEGIN
    PERFORM public.validate_question_answer_key(
      'dnd','{"q":"[1] and [2]","o":["A","B"]}'::jsonb,'{"1":1}'::jsonb
    );
    RAISE EXCEPTION 'Incomplete DND slots were accepted.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  BEGIN
    PERFORM public.validate_question_answer_key(
      'dnd','{"q":"[1]","o":["A","B"]}'::jsonb,'{"1":2147483648}'::jsonb
    );
    RAISE EXCEPTION 'Out-of-range DND option was accepted.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  -- NULL scope must be rejected explicitly, not deferred to a table constraint.
  v_rejected := false;
  BEGIN
    PERFORM public.admin_save_question(
      NULL,NULL,NULL,'mc',
      '{"q":"Question?","o":["A","B"]}'::jsonb,'0'::jsonb,
      '', '{}'::jsonb, '{}'::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'admin_save_question accepted a NULL scope.';
  END IF;

  -- Exercise the real authoring RPC: a DND question must save successfully.
  v_saved_version := public.admin_save_question(
    NULL,'bank',NULL,'dnd',
    '{"q":"Ghép [1] với [2]","o":["A","B","C"]}'::jsonb,
    '{"1":1,"2":3}'::jsonb,
    '', '{}'::jsonb, '{}'::jsonb
  );
  IF v_saved_version IS NULL THEN
    RAISE EXCEPTION 'admin_save_question did not return a question version.';
  END IF;

  -- Exercise admin_set_question_answer_key, including its immutable-key behavior.
  INSERT INTO public.questions(id,scope,owner_exam_id,created_by)
  VALUES ('10000000-0000-4000-8000-000000000001','bank',NULL,auth.uid());
  INSERT INTO public.question_versions(id,question_id,version_no,question_type,content,created_by)
  VALUES (
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',1,'mc',
    '{"q":"Question?","o":["A","B"]}'::jsonb,auth.uid()
  );

  IF public.admin_set_question_answer_key(
    '20000000-0000-4000-8000-000000000001','0'::jsonb
  ) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'admin_set_question_answer_key failed to insert a valid key.';
  END IF;
  IF public.admin_set_question_answer_key(
    '20000000-0000-4000-8000-000000000001','0'::jsonb
  ) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'admin_set_question_answer_key did not preserve idempotent behavior.';
  END IF;

  -- Publish a valid draft and verify its state transition.
  INSERT INTO public.exams(id,title,duration_minutes)
  VALUES ('40000000-0000-4000-8000-000000000001','Test exam',60);
  INSERT INTO public.exam_versions(id,exam_id,version_no,title,duration_minutes,status)
  VALUES (
    '30000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',1,'Test exam',60,'draft'
  );
  INSERT INTO public.exam_version_questions(
    exam_version_id,exam_id,question_version_id,question_id,position
  ) VALUES (
    '30000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',1
  );

  v_result := public.admin_publish_exam_version('30000000-0000-4000-8000-000000000001');
  IF v_result->>'success' IS DISTINCT FROM 'true'
     OR (SELECT status FROM public.exam_versions WHERE id='30000000-0000-4000-8000-000000000001') <> 'published' THEN
    RAISE EXCEPTION 'A valid exam draft did not publish.';
  END IF;

  -- Invalid answer keys must block publication and leave the draft unchanged.
  INSERT INTO public.questions(id,scope,created_by)
  VALUES ('10000000-0000-4000-8000-000000000002','bank',auth.uid());
  INSERT INTO public.question_versions(id,question_id,version_no,question_type,content,created_by)
  VALUES (
    '20000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',1,'mc',
    '{"q":"Question?","o":["A","B"]}'::jsonb,auth.uid()
  );
  INSERT INTO public.question_answer_keys(question_version_id,answer_key)
  VALUES ('20000000-0000-4000-8000-000000000002','2'::jsonb);
  INSERT INTO public.exams(id,title,duration_minutes)
  VALUES ('40000000-0000-4000-8000-000000000002','Invalid exam',60);
  INSERT INTO public.exam_versions(id,exam_id,version_no,title,duration_minutes,status)
  VALUES (
    '30000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000002',1,'Invalid exam',60,'draft'
  );
  INSERT INTO public.exam_version_questions(
    exam_version_id,exam_id,question_version_id,question_id,position
  ) VALUES (
    '30000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',1
  );

  v_rejected := false;
  BEGIN
    PERFORM public.admin_publish_exam_version('30000000-0000-4000-8000-000000000002');
  EXCEPTION WHEN OTHERS THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'An exam with an invalid answer key was published.';
  END IF;
  IF (SELECT status FROM public.exam_versions WHERE id='30000000-0000-4000-8000-000000000002') <> 'draft' THEN
    RAISE EXCEPTION 'A rejected exam publication changed the draft status.';
  END IF;
END;
$tests$;
