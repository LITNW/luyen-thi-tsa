-- Question-local media and reusable shared-stimulus regression.
-- Run only against the disposable recovered migration-chain database.

begin;

do $tests$
declare
  v_admin uuid := '00000000-0000-4000-8000-000000000001';
  v_student uuid := '00000000-0000-4000-8000-000000000002';
  v_exam uuid := '71000000-0000-4000-8000-000000000001';
  v_exam_version uuid := '71000000-0000-4000-8000-000000000002';
  v_stimulus uuid := '71000000-0000-4000-8000-000000000003';
  v_stimulus_version uuid := '71000000-0000-4000-8000-000000000004';
  v_offering uuid;
  v_save jsonb;
  v_admin_payload jsonb;
  v_public_payload jsonb;
  v_question_count integer;
  v_shared_count integer;
begin
  perform set_config('request.jwt.claim.sub',v_admin::text,true);

  if not exists (
    select 1 from public.profiles
    where id=v_admin and role='admin' and status='active'
  ) then
    raise exception 'Question media regression requires the seeded active Admin.';
  end if;

  if not exists (
    select 1 from public.profiles
    where id=v_student and role='student' and status='active'
  ) then
    raise exception 'Question media regression requires the seeded active student.';
  end if;

  select es.id into v_offering
  from public.education_subjects es
  join public.education_levels l on l.id=es.education_level_id
  join public.subjects s on s.id=es.subject_id
  where l.code='thpt' and es.education_node_id is null and s.code='mathematics'
  limit 1;

  if v_offering is null then
    insert into public.education_subjects(
      education_level_id,education_node_id,subject_id,display_name
    )
    select l.id,null,s.id,'CI Media Mathematics'
    from public.education_levels l
    cross join public.subjects s
    where l.code='thpt' and s.code='mathematics'
    returning id into v_offering;
  end if;

  insert into public.stimuli(id,status,created_by)
  values(v_stimulus,'draft',v_admin);

  insert into public.stimulus_versions(
    id,stimulus_id,version_no,stimulus_type,content,metadata,created_by
  ) values (
    v_stimulus_version,
    v_stimulus,
    1,
    'mixed',
    jsonb_build_object(
      'body','Ngữ liệu dùng chung cho hai câu hỏi.',
      'media',jsonb_build_array(jsonb_build_object(
        'path','question-media/ci-admin/shared.png',
        'alt','Biểu đồ dùng chung',
        'caption','Biểu đồ trong ngữ liệu'
      ))
    ),
    jsonb_build_object('title','Ngữ liệu kiểm thử'),
    v_admin
  );

  insert into public.exams(id,title,description,duration_minutes,created_by,education_subject_id)
  values(v_exam,'Question media regression','Disposable CI fixture',30,v_admin,v_offering);

  insert into public.exam_versions(
    id,exam_id,version_no,title,description,duration_minutes,status,created_by
  ) values (
    v_exam_version,v_exam,1,'Question media regression','Disposable CI fixture',30,'draft',v_admin
  );

  v_save := public.admin_save_exam_content(
    v_exam_version,
    'Question media regression',
    'Disposable CI fixture',
    30,
    jsonb_build_array(
      jsonb_build_object(
        'scope','bank',
        'type','mc',
        'content',jsonb_build_object(
          'q','Câu hỏi thứ nhất?',
          'o',jsonb_build_array('A','B'),
          'stimulus_version_id',v_stimulus_version,
          'media',jsonb_build_array(jsonb_build_object(
            'path','question-media/ci-admin/q1.png',
            'alt','Hình riêng câu 1',
            'caption','Ảnh riêng'
          ))
        ),
        'answer_key',1,
        'explanation','',
        'grading_config','{}'::jsonb,
        'source_metadata','{}'::jsonb,
        'points',1
      ),
      jsonb_build_object(
        'scope','bank',
        'type','mc',
        'content',jsonb_build_object(
          'q','Câu hỏi thứ hai?',
          'o',jsonb_build_array('A','B'),
          'stimulus_version_id',v_stimulus_version
        ),
        'answer_key',0,
        'explanation','',
        'grading_config','{}'::jsonb,
        'source_metadata','{}'::jsonb,
        'points',1
      )
    ),
    false
  );

  if v_save->>'success' is distinct from 'true' then
    raise exception 'Legacy editor save rejected media/stimulus content: %',v_save;
  end if;

  select count(*),count(*) filter (where qv.stimulus_version_id=v_stimulus_version)
  into v_question_count,v_shared_count
  from public.exam_version_questions evq
  join public.question_versions qv on qv.id=evq.question_version_id
  where evq.exam_version_id=v_exam_version;

  if v_question_count<>2 or v_shared_count<>2 then
    raise exception 'Both questions must retain the same shared stimulus version.';
  end if;

  v_admin_payload := public.admin_get_exam_version(v_exam_version);
  if jsonb_array_length(v_admin_payload->'questions')<>2
     or v_admin_payload->'questions'->0->'content'->'stimulus'->>'version_id'
        is distinct from v_stimulus_version::text
     or jsonb_array_length(v_admin_payload->'questions'->0->'content'->'media')<>1 then
    raise exception 'Admin authoring read lost question-local or shared stimulus media.';
  end if;

  insert into storage.objects(bucket_id,name,owner_id,metadata)
  values
    ('lit-question-media','question-media/ci-admin/shared.png',v_admin,'{"mimetype":"image/png"}'),
    ('lit-question-media','question-media/ci-admin/q1.png',v_admin,'{"mimetype":"image/png"}');

  -- Draft assets must not be readable by students before publication.
  perform set_config('request.jwt.claim.sub',v_student::text,true);
  set local role authenticated;
  if (select count(*) from storage.objects where bucket_id='lit-question-media')<>0 then
    raise exception 'Student unexpectedly read media belonging only to a draft exam.';
  end if;
  reset role;

  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_save := public.admin_publish_exam_version(v_exam_version);
  if v_save->>'success' is distinct from 'true' then
    raise exception 'Media fixture exam did not publish: %',v_save;
  end if;

  v_public_payload := public.get_published_exam(v_exam_version);
  if jsonb_array_length(v_public_payload->'questions')<>2
     or v_public_payload->'questions'->0->'content'->'stimulus'->>'version_id'
        is distinct from v_stimulus_version::text
     or v_public_payload->'questions'->0->'content' ? 'answer_key'
     or v_public_payload->'questions'->0->'content' ? 'explanation' then
    raise exception 'Student exam payload lost stimulus data or leaked grading fields.';
  end if;

  perform set_config('request.jwt.claim.sub',v_student::text,true);
  set local role authenticated;
  if (select count(*) from storage.objects where bucket_id='lit-question-media')<>2 then
    raise exception 'Student could not read exactly the media assets referenced by the published exam.';
  end if;
  reset role;
end;
$tests$;

rollback;
