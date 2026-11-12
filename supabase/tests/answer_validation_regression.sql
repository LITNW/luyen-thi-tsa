-- Manual regression tests for 20261112170000_centralize_exam_answer_validation.sql.
-- Run after applying the migration in a disposable/local database, not Production.

DO $tests$
BEGIN
  -- Valid examples for all five supported question types.
  PERFORM public.validate_question_answer_key(
    'mc', '{"q":"Question?","o":["A","B","C","D"]}'::jsonb, '1'::jsonb
  );
  PERFORM public.validate_question_answer_key(
    'ms', '{"q":"Question?","o":["A","B","C","D"]}'::jsonb, '[0,2]'::jsonb
  );
  PERFORM public.validate_question_answer_key(
    'tf', '{"q":"Question?","o":["a","b","c","d"]}'::jsonb, '[true,false,true,false]'::jsonb
  );
  PERFORM public.validate_question_answer_key(
    'num', '{"q":"Question?","o":[]}'::jsonb, '12.5'::jsonb
  );
  PERFORM public.validate_question_answer_key(
    'dnd', '{"q":"[1] and [2]","o":["A","B","C"]}'::jsonb, '{"1":1,"2":3}'::jsonb
  );

  -- Invalid values must be rejected with SQLSTATE 22023.
  BEGIN
    PERFORM public.validate_question_answer_key(
      'mc', '{"q":"Question?","o":["A","B"]}'::jsonb, '2'::jsonb
    );
    RAISE EXCEPTION 'Expected invalid MC answer to be rejected.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  BEGIN
    PERFORM public.validate_question_answer_key(
      'ms', '{"q":"Question?","o":["A","B","C"]}'::jsonb, '[1,1]'::jsonb
    );
    RAISE EXCEPTION 'Expected duplicate MS answer to be rejected.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  BEGIN
    PERFORM public.validate_question_answer_key(
      'tf', '{"q":"Question?","o":["a","b"]}'::jsonb, '[true]'::jsonb
    );
    RAISE EXCEPTION 'Expected incomplete TF answer to be rejected.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  BEGIN
    PERFORM public.validate_question_answer_key(
      'num', '{"q":"Question?","o":[]}'::jsonb, '"12.5"'::jsonb
    );
    RAISE EXCEPTION 'Expected non-numeric NUM answer to be rejected.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  BEGIN
    PERFORM public.validate_question_answer_key(
      'dnd', '{"q":"[1] and [2]","o":["A","B"]}'::jsonb, '{"1":1,"2":1}'::jsonb
    );
    RAISE EXCEPTION 'Expected reused DND option to be rejected.';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;
END;
$tests$;
