-- M1 regression: subjects, taxonomy hierarchy, question-version classification,
-- reusable stimuli/version immutability, and direct-table RLS boundaries.
-- Run only against the disposable CI/local Supabase database.

begin;

do $tests$
declare
  v_admin uuid := '00000000-0000-4000-8000-000000000001';
  v_student uuid := '00000000-0000-4000-8000-000000000002';
  v_math uuid;
  v_reading uuid;
  v_science uuid;
  v_root uuid := '61000000-0000-4000-8000-000000000001';
  v_topic uuid := '61000000-0000-4000-8000-000000000002';
  v_skill uuid := '61000000-0000-4000-8000-000000000003';
  v_stimulus uuid := '62000000-0000-4000-8000-000000000001';
  v_stimulus_version uuid := '62000000-0000-4000-8000-000000000002';
  v_exam uuid := '63000000-0000-4000-8000-000000000001';
  v_exam_version uuid := '63000000-0000-4000-8000-000000000002';
  v_question_version uuid;
  v_subject_count integer;
  v_save jsonb;
begin
  perform set_config('request.jwt.claim.sub',v_admin::text,true);

  if not exists (
    select 1 from public.profiles
    where id=v_admin and role='admin' and status='active'
  ) then
    raise exception 'M1 regression requires the seeded active CI admin.';
  end if;

  select id into v_math from public.subjects where code='mathematics';
  select id into v_reading from public.subjects where code='reading';
  select id into v_science from public.subjects where code='science';
  if v_math is null or v_reading is null or v_science is null
     or (select count(*) from public.subjects where code in ('mathematics','reading','science')) <> 3 then
    raise exception 'The three canonical subjects were not seeded exactly once.';
  end if;

  -- Confirm there was no automatic classification/backfill of legacy question versions.
  if exists (select 1 from public.question_version_taxonomy) then
    raise exception 'M1 must not auto-assign existing question versions to taxonomy.';
  end if;

  -- Create a second identity for the student RLS test; fixture trigger creates its profile.
  insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
  values (
    v_student,'m1-student@example.test',now(),
    '{"display_name":"M1 Student"}'::jsonb
  );
  if not exists (
    select 1 from public.profiles
    where id=v_student and role='student' and status='active'
  ) then
    raise exception 'The disposable student profile was not created.';
  end if;

  insert into public.taxonomy_nodes(id,subject_id,parent_id,node_type,code,name)
  values (v_root,v_math,null,'domain','algebra','Đại số');
  insert into public.taxonomy_nodes(id,subject_id,parent_id,node_type,code,name)
  values (v_topic,v_math,v_root,'topic','linear_equations','Phương trình tuyến tính');
  insert into public.taxonomy_nodes(id,subject_id,parent_id,node_type,code,name)
  values (v_skill,v_math,v_topic,'skill','solve_systems','Giải hệ phương trình');

  -- Composite FK must reject a parent from another subject.
  begin
    insert into public.taxonomy_nodes(subject_id,parent_id,node_type,code,name)
    values (v_reading,v_root,'topic','invalid_cross_subject','Invalid');
    raise exception 'Cross-subject taxonomy parent was unexpectedly accepted.';
  exception when foreign_key_violation then
    null;
  end;

  -- A node cannot become its own descendant.
  begin
    update public.taxonomy_nodes set parent_id=v_skill where id=v_root;
    raise exception 'Taxonomy cycle was unexpectedly accepted.';
  exception when check_violation then
    null;
  end;

  -- Root codes are unique within a subject even though parent_id is NULL.
  begin
    insert into public.taxonomy_nodes(subject_id,parent_id,node_type,code,name)
    values (v_math,null,'domain','algebra','Duplicate root');
    raise exception 'Duplicate root taxonomy code was unexpectedly accepted.';
  exception when unique_violation then
    null;
  end;

  insert into public.stimuli(id,status,created_by)
  values (v_stimulus,'draft',v_admin);
  insert into public.stimulus_versions(
    id,stimulus_id,version_no,stimulus_type,content,metadata,created_by
  ) values (
    v_stimulus_version,v_stimulus,1,'text',
    '{"body":"A reusable reading passage."}'::jsonb,
    '{"language":"vi"}'::jsonb,v_admin
  );

  -- Stimulus version rows are immutable, including deletion.
  begin
    update public.stimulus_versions
    set content='{"body":"changed"}'::jsonb
    where id=v_stimulus_version;
    raise exception 'Stimulus version update was unexpectedly accepted.';
  exception when sqlstate '55000' then
    null;
  end;
  begin
    delete from public.stimulus_versions where id=v_stimulus_version;
    raise exception 'Stimulus version deletion was unexpectedly accepted.';
  exception when sqlstate '55000' then
    null;
  end;

  insert into public.exams(id,title,description,duration_minutes,created_by)
  values (v_exam,'M1 taxonomy guard test','Disposable CI fixture',30,v_admin);
  insert into public.exam_versions(
    id,exam_id,version_no,title,description,duration_minutes,status,created_by
  ) values (
    v_exam_version,v_exam,1,'M1 taxonomy guard test','Disposable CI fixture',30,'draft',v_admin
  );

  v_save := public.admin_save_exam_content(
    v_exam_version,
    'M1 taxonomy guard test',
    'Disposable CI fixture',
    30,
    jsonb_build_array(jsonb_build_object(
      'scope','bank',
      'type','mc',
      'content',jsonb_build_object('q','M1 taxonomy guard question?','o',jsonb_build_array('A','B')),
      'answer_key',1,
      'explanation','',
      'grading_config','{}'::jsonb,
      'source_metadata','{}'::jsonb,
      'points',1
    )),
    false
  );
  if v_save->>'success' is distinct from 'true' then
    raise exception 'Could not create the disposable question through the legacy authoring RPC: %',v_save;
  end if;

  select question_version_id into v_question_version
  from public.exam_version_questions
  where exam_version_id=v_exam_version;

  insert into public.question_version_taxonomy(
    question_version_id,taxonomy_node_id,relation_type
  ) values (v_question_version,v_topic,'primary_topic');
  insert into public.question_version_taxonomy(
    question_version_id,taxonomy_node_id,relation_type
  ) values (v_question_version,v_skill,'skill');

  -- Relation types must match taxonomy node levels.
  begin
    insert into public.question_version_taxonomy(
      question_version_id,taxonomy_node_id,relation_type
    ) values (v_question_version,v_topic,'skill');
    raise exception 'Mismatched taxonomy relation type was unexpectedly accepted.';
  exception when check_violation then
    null;
  end;

  -- Only one primary topic is allowed for a question version.
  begin
    insert into public.question_version_taxonomy(
      question_version_id,taxonomy_node_id,relation_type
    ) values (v_question_version,v_root,'primary_topic');
    raise exception 'A second primary topic was unexpectedly accepted.';
  exception when unique_violation then
    null;
  end;

  -- Referenced taxonomy identity cannot be rewritten.
  begin
    update public.taxonomy_nodes set code='renamed_algebra' where id=v_topic;
    raise exception 'Referenced taxonomy identity was unexpectedly mutable.';
  exception when check_violation then
    null;
  end;

  perform public.admin_publish_exam_version(v_exam_version);

  -- Classification is frozen after publication; INSERT/UPDATE/DELETE all fail.
  begin
    delete from public.question_version_taxonomy
    where question_version_id=v_question_version and taxonomy_node_id=v_topic;
    raise exception 'Published question taxonomy deletion was unexpectedly accepted.';
  exception when check_violation then
    null;
  end;
  begin
    update public.question_version_taxonomy
    set relation_type='secondary_topic'
    where question_version_id=v_question_version and taxonomy_node_id=v_topic;
    raise exception 'Published question taxonomy update was unexpectedly accepted.';
  exception when check_violation then
    null;
  end;
  begin
    insert into public.question_version_taxonomy(
      question_version_id,taxonomy_node_id,relation_type
    ) values (v_question_version,v_root,'secondary_topic');
    raise exception 'Published question taxonomy insertion was unexpectedly accepted.';
  exception when check_violation then
    null;
  end;

  -- The RPC must not be executable by anon.
  if has_function_privilege('anon','public.list_active_subjects()','EXECUTE') then
    raise exception 'Anonymous role must not execute list_active_subjects().';
  end if;
end;
$tests$;

rollback;
-- Exercise table grants and RLS under the actual authenticated database role.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $admin_rls$
declare v_count integer;
begin
  select count(*) into v_count from public.subjects;
  if v_count < 3 then
    raise exception 'Admin RLS policy does not expose the subject catalogue.';
  end if;
end;
$admin_rls$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
do $student_rls$
declare v_count integer;
begin
  select count(*) into v_count from public.subjects;
  if v_count <> 0 then
    raise exception 'Student direct SELECT unexpectedly exposed private subject rows.';
  end if;

  select count(*) into v_count from public.list_active_subjects();
  if v_count <> 3 then
    raise exception 'Authenticated student subject RPC should return exactly three active subjects; got %.',v_count;
  end if;

  begin
    insert into public.subjects(code,name) values ('student_forbidden','Forbidden');
    raise exception 'Student INSERT into subjects was unexpectedly accepted.';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into public.stimuli(status,created_by) values ('draft','00000000-0000-4000-8000-000000000002');
    raise exception 'Student INSERT into stimuli was unexpectedly accepted.';
  exception when insufficient_privilege then
    null;
  end;
end;
$student_rls$;
reset role;

