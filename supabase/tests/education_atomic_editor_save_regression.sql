-- Atomic editor save + education placement regression.

begin;

do $tests$
declare
  v_admin uuid := '00000000-0000-4000-8000-000000000001';
  v_student uuid := '00000000-0000-4000-8000-000000000005';
  v_thpt uuid;
  v_math uuid;
  v_offer uuid := '67000000-0000-4000-8000-000000000001';
  v_result jsonb;
  v_exam_id uuid;
  v_version_id uuid;
  v_status text;
  v_rejected boolean;
  v_questions jsonb := '[
    {
      "mapping_id": null,
      "question_id": null,
      "scope": "exam",
      "owner_exam_id": null,
      "type": "mc",
      "content": {"q":"1 + 1 = ?","o":["1","2"]},
      "answer_key": 1,
      "explanation": "Phép cộng cơ bản.",
      "grading_config": {},
      "source_metadata": {},
      "points": 1
    }
  ]'::jsonb;
begin
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
  values(v_student,'education-editor-student@example.test',now(),'{"display_name":"Editor Student"}'::jsonb);

  select id into v_thpt from public.education_levels where code='thpt';
  select id into v_math from public.subjects where code='mathematics';

  insert into public.education_subjects(
    id,education_level_id,education_node_id,subject_id,display_name
  ) values(v_offer,v_thpt,null,v_math,'Editor Mathematics');

  -- New editor contract creates a draft with its placement atomically.
  v_result := public.admin_save_exam_content_with_education(
    null,'Education editor draft','Regression fixture',30,v_questions,v_offer,null,false
  );
  v_exam_id := (v_result->>'exam_id')::uuid;
  v_version_id := (v_result->>'exam_version_id')::uuid;

  if (select education_subject_id from public.exams where id=v_exam_id) is distinct from v_offer then
    raise exception 'Editor save did not persist education placement.';
  end if;
  select status into v_status from public.exam_versions where id=v_version_id;
  if v_status <> 'draft' then
    raise exception 'Editor draft unexpectedly changed status: %',v_status;
  end if;

  -- The same contract assigns the education path before publication.
  v_result := public.admin_save_exam_content_with_education(
    null,'Education editor published','Regression fixture',30,v_questions,v_offer,null,true
  );
  v_exam_id := (v_result->>'exam_id')::uuid;
  v_version_id := (v_result->>'exam_version_id')::uuid;

  if (select education_subject_id from public.exams where id=v_exam_id) is distinct from v_offer then
    raise exception 'Published editor save lost education placement.';
  end if;
  select status into v_status from public.exam_versions where id=v_version_id;
  if v_status <> 'published' then
    raise exception 'Editor publish failed after placement: %',v_status;
  end if;

  v_rejected := false;
  begin
    perform public.admin_save_exam_content_with_education(
      null,'Missing placement','Regression fixture',30,v_questions,null,null,false
    );
  exception when raise_exception then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Editor save without an education subject was unexpectedly accepted.';
  end if;

  if has_function_privilege('anon','public.admin_save_exam_content_with_education(uuid,text,text,integer,jsonb,uuid,uuid,boolean)','EXECUTE') then
    raise exception 'Anonymous role must not execute the education editor save RPC.';
  end if;

  perform set_config('request.jwt.claim.sub',v_student::text,true);
  v_rejected := false;
  begin
    perform public.admin_save_exam_content_with_education(
      null,'Student attempt','Regression fixture',30,v_questions,v_offer,null,false
    );
  exception when raise_exception then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Student unexpectedly used the Admin education editor save RPC.';
  end if;
end;
$tests$;

rollback;
