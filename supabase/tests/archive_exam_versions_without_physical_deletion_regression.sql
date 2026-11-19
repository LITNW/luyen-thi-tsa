-- Regression: archiving never physically deletes exam versions, mappings, or attempts.
-- Uses the isolated CI Admin seeded by the migration-chain workflows.
begin;

do $test$
declare
  v_admin uuid := '00000000-0000-4000-8000-000000000001';
  v_exam uuid := '72000000-0000-4000-8000-000000000001';
  v_exam_version uuid := '72000000-0000-4000-8000-000000000002';
  v_question uuid := '72000000-0000-4000-8000-000000000003';
  v_question_version uuid := '72000000-0000-4000-8000-000000000004';
  v_mapping uuid := '72000000-0000-4000-8000-000000000005';
  v_attempt uuid := '72000000-0000-4000-8000-000000000006';
  v_result jsonb;
  v_audit_count integer;
begin
  perform set_config('request.jwt.claim.sub', v_admin::text, true);

  insert into public.exams(id,title,description,duration_minutes,created_by)
  values (v_exam,'Archive-only regression','Disposable transaction fixture',30,v_admin);

  insert into public.exam_versions(
    id,exam_id,version_no,title,description,duration_minutes,status,created_by
  ) values (
    v_exam_version,v_exam,1,'Archive-only regression','Disposable transaction fixture',30,'draft',v_admin
  );

  insert into public.questions(id,scope,created_by)
  values (v_question,'bank',v_admin);

  insert into public.question_versions(
    id,question_id,version_no,question_type,content,created_by
  ) values (
    v_question_version,v_question,1,'mc',
    jsonb_build_object('q','Archive-only regression question?','o',jsonb_build_array('A','B')),
    v_admin
  );

  insert into public.exam_version_questions(
    id,exam_version_id,exam_id,question_version_id,question_id,position,points
  ) values (
    v_mapping,v_exam_version,v_exam,v_question_version,v_question,1,1
  );

  insert into public.attempts(
    id,user_id,exam_id,exam_version_id,max_score
  ) values (
    v_attempt,v_admin,v_exam,v_exam_version,1
  );

  v_result := public.admin_delete_exam_version(v_exam_version);

  if v_result->>'success' is distinct from 'true'
     or v_result->>'archived' is distinct from 'true'
     or v_result->>'deleted' is distinct from 'false'
     or (v_result->>'attempt_count')::integer <> 1
     or (v_result->>'question_count')::integer <> 1 then
    raise exception 'Archive RPC returned unexpected result: %',v_result;
  end if;

  if not exists (
    select 1 from public.exam_versions
    where id=v_exam_version and archived_at is not null
  ) then
    raise exception 'Exam version was deleted or not marked archived.';
  end if;

  if not exists (select 1 from public.exam_version_questions where id=v_mapping) then
    raise exception 'Question mapping was physically deleted during archive.';
  end if;

  if not exists (select 1 from public.attempts where id=v_attempt) then
    raise exception 'Attempt history was physically deleted during archive.';
  end if;

  select count(*) into v_audit_count
  from public.audit_logs
  where actor_id=v_admin
    and action='exam_version.archive'
    and target_type='exam_version'
    and target_id=v_exam_version::text
    and details->>'attempt_count'='1'
    and details->>'question_mapping_count'='1';

  if v_audit_count <> 1 then
    raise exception 'Expected one complete archive audit record, found %.',v_audit_count;
  end if;

  -- A repeated archive must fail without deleting or rewriting anything.
  begin
    perform public.admin_delete_exam_version(v_exam_version);
    raise exception 'Expected repeated archive to be rejected.';
  exception when others then
    if sqlerrm <> 'Phiên bản này đã được ẩn trước đó.' then
      raise;
    end if;
  end;

  if not has_function_privilege('authenticated','public.admin_delete_exam_version(uuid)','EXECUTE') then
    raise exception 'The shared migration unexpectedly changed the clean-install authenticated EXECUTE grant.';
  end if;
end;
$test$;

rollback;
