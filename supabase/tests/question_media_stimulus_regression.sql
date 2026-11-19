-- Question-local media and reusable shared-stimulus regression.
-- Run only against the disposable recovered migration-chain database.

begin;

create temporary table media_fixture_ids(stimulus_id uuid,stimulus_version_id uuid,second_stimulus_id uuid,second_stimulus_version_id uuid,exam_version_id uuid) on commit drop;

do $setup$
declare
  v_admin uuid := '00000000-0000-4000-8000-000000000001';
  v_student uuid := '00000000-0000-4000-8000-000000000002';
  v_exam uuid := '71000000-0000-4000-8000-000000000001';
  v_exam_version uuid := '71000000-0000-4000-8000-000000000002';
  v_stimulus uuid;
  v_stimulus_version uuid;
  v_stimulus_save jsonb;
  v_second_stimulus_save jsonb;
  v_second_stimulus uuid;
  v_second_stimulus_version uuid;
  v_offering uuid;
  v_save jsonb;
  v_admin_payload jsonb;
  v_question_count integer;
  v_shared_count integer;
begin
  perform set_config('request.jwt.claim.sub',v_admin::text,true);

  if (select prosecdef from pg_proc where oid='public.admin_save_stimulus_version(uuid,text,jsonb,jsonb)'::regprocedure) then
    raise exception 'Shared stimulus authoring RPC must run as SECURITY INVOKER.';
  end if;

  insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
  values(v_student,'ci-student@example.test',now(),' {"display_name":"CI Student"}'::jsonb)
  on conflict (id) do nothing;
  update public.profiles set role='student',status='active' where id=v_student;

  if not exists (
    select 1 from public.profiles
    where id=v_admin and role='admin' and status='active'
  ) then
    raise exception 'Question media regression requires the seeded active Admin.';
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

  v_stimulus_save := public.admin_save_stimulus_version(
    null::uuid,
    'mixed',
    jsonb_build_object(
      'body','Ngữ liệu dùng chung cho hai câu hỏi.',
      'media',jsonb_build_array(jsonb_build_object(
        'path','question-media/ci-admin/shared.png',
        'alt','Biểu đồ dùng chung',
        'caption','Biểu đồ trong ngữ liệu'
      ))
    ),
    jsonb_build_object('title','Ngữ liệu kiểm thử','question_indices',jsonb_build_array(1,2))
  );
  v_stimulus := (v_stimulus_save->>'stimulus_id')::uuid;
  v_stimulus_version := (v_stimulus_save->>'stimulus_version_id')::uuid;
  if v_stimulus is null or v_stimulus_version is null then
    raise exception 'Shared stimulus RPC did not return identity/version IDs.';
  end if;
  v_second_stimulus_save := public.admin_save_stimulus_version(
    null::uuid,
    'image',
    jsonb_build_object(
      'body','Ngữ liệu độc lập thứ hai.',
      'media',jsonb_build_array(jsonb_build_object(
        'path','question-media/ci-admin/shared-two.png',
        'alt','Hình thuộc ngữ liệu thứ hai',
        'caption','Ảnh ngữ liệu thứ hai'
      ))
    ),
    jsonb_build_object('title','Ngữ liệu độc lập thứ hai','question_indices',jsonb_build_array(1))
  );
  v_second_stimulus := (v_second_stimulus_save->>'stimulus_id')::uuid;
  v_second_stimulus_version := (v_second_stimulus_save->>'stimulus_version_id')::uuid;
  if v_second_stimulus is null or v_second_stimulus_version is null
     or v_second_stimulus=v_stimulus then
    raise exception 'The second stimulus group must have an independent identity and version.';
  end if;
  insert into media_fixture_ids values(v_stimulus,v_stimulus_version,v_second_stimulus,v_second_stimulus_version,v_exam_version);

  insert into public.exams(id,title,description,duration_minutes,created_by,education_subject_id)
  values(v_exam,'Question media regression','Disposable CI fixture',30,v_admin,v_offering);

  insert into public.exam_versions(
    id,exam_id,version_no,title,description,duration_minutes,status,created_by
  ) values (
    v_exam_version,v_exam,1,'Question media regression','Disposable CI fixture',30,'draft',v_admin
  );

  v_save := public.admin_save_exam_content_with_education(
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
          'stimulus_version_ids',jsonb_build_array(v_stimulus_version::text,v_second_stimulus_version::text),
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
    v_offering,
    null,
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

  select count(*) into v_shared_count
  from public.question_version_stimuli qvs
  join public.exam_version_questions evq on evq.question_version_id=qvs.question_version_id
  where evq.exam_version_id=v_exam_version;
  if v_question_count<>2 or v_shared_count<>3 then
    raise exception 'Expected two questions with three independent group links, got questions %, links %.',v_question_count,v_shared_count;
  end if;

  v_admin_payload := public.admin_get_exam_version(v_exam_version);
  if jsonb_array_length(v_admin_payload->'questions')<>2
     or jsonb_array_length(v_admin_payload->'questions'->0->'content'->'stimuli')<>2
     or v_admin_payload->'questions'->0->'content'->'stimuli'->1->>'version_id'
        is distinct from v_second_stimulus_version::text
     or jsonb_array_length(v_admin_payload->'questions'->0->'content'->'media')<>1 then
    raise exception 'Admin authoring read lost question-local media or one of the independent stimulus groups.';
  end if;

  insert into storage.objects(bucket_id,name,owner_id,metadata)
  values
    ('lit-question-media','question-media/ci-admin/shared.png',v_admin::text,'{"mimetype":"image/png"}'),
    ('lit-question-media','question-media/ci-admin/shared-two.png',v_admin::text,'{"mimetype":"image/png"}'),
    ('lit-question-media','question-media/ci-admin/q1.png',v_admin::text,'{"mimetype":"image/png"}');
end;
$setup$;

-- Exercise the authoring RPC with the actual authenticated role so RLS and
-- function EXECUTE grants are evaluated exactly as they are in the browser.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $authenticated_stimulus_rpc$
declare
  v_result jsonb;
begin
  v_result := public.admin_save_stimulus_version(
    null::uuid,
    'text',
    jsonb_build_object('body','Authenticated RPC permission regression','media','[]'::jsonb),
    jsonb_build_object('title','Authenticated RPC permission regression')
  );
  if v_result->>'stimulus_id' is null or v_result->>'stimulus_version_id' is null then
    raise exception 'Authenticated Admin could not create a shared stimulus version.';
  end if;
end;
$authenticated_stimulus_rpc$;
reset role;

-- Draft assets must not be readable by students before publication.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
do $draft_media_rls$
begin
  if (select count(*) from storage.objects where bucket_id='lit-question-media')<>0 then
    raise exception 'Student unexpectedly read media belonging only to a draft exam.';
  end if;
end;
$draft_media_rls$;
reset role;

do $publish$
declare
  v_admin uuid := '00000000-0000-4000-8000-000000000001';
  v_exam_version uuid := '71000000-0000-4000-8000-000000000002';
  v_stimulus_version uuid;
  v_save jsonb;
  v_public_payload jsonb;
begin
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  select stimulus_version_id into v_stimulus_version from media_fixture_ids limit 1;
  v_save := public.admin_publish_exam_version(v_exam_version);
  if v_save->>'success' is distinct from 'true' then
    raise exception 'Media fixture exam did not publish: %',v_save;
  end if;

  v_public_payload := public.get_published_exam(v_exam_version);
  if jsonb_array_length(v_public_payload->'questions')<>2
     or jsonb_array_length(v_public_payload->'questions'->0->'content'->'stimuli')<>2
     or v_public_payload->'questions'->0->'content'->'stimuli'->1->>'version_id'
        is distinct from (select second_stimulus_version_id::text from media_fixture_ids)
     or v_public_payload->'questions'->0->'content' ? 'answer_key'
     or v_public_payload->'questions'->0->'content' ? 'explanation' then
    raise exception 'Student exam payload lost stimulus data or leaked grading fields.';
  end if;
end;
$publish$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
do $published_media_rls$
declare
  v_count integer;
  v_shared_allowed boolean;
  v_question_allowed boolean;
  v_second_shared_allowed boolean;
  v_uid uuid;
  v_profile_status text;
begin
  v_uid := auth.uid();
  select status into v_profile_status from public.profiles where id=v_uid;
  v_shared_allowed := private.lit_can_read_question_media('question-media/ci-admin/shared.png');
  v_question_allowed := private.lit_can_read_question_media('question-media/ci-admin/q1.png');
  v_second_shared_allowed := private.lit_can_read_question_media('question-media/ci-admin/shared-two.png');
  select count(*) into v_count from storage.objects where bucket_id='lit-question-media';
  if v_count<>3 or not v_second_shared_allowed then
    raise exception 'Student media access mismatch: visible %, shared allowed %, second shared allowed %, question allowed %, uid %, profile status %.',
      v_count,v_shared_allowed,v_second_shared_allowed,v_question_allowed,v_uid,v_profile_status;
  end if;
end;
$published_media_rls$;
reset role;

-- Archived published exams must not expose either the exam payload or its media.
select set_config('app.allow_exam_version_delete','on',true);
update public.exam_versions
set archived_at=now()
where id='71000000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
do $archived_media_gate$
declare
  v_rejected boolean := false;
begin
  if private.lit_can_read_question_media('question-media/ci-admin/shared.png') then
    raise exception 'Student can read media after its published exam version is archived.';
  end if;

  begin
    perform public.get_published_exam('71000000-0000-4000-8000-000000000002');
  exception when others then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Student can still read the exam payload after its version is archived.';
  end if;

  if exists (select 1 from storage.objects where bucket_id='lit-question-media') then
    raise exception 'Storage RLS still exposes media after its published exam version is archived.';
  end if;
end;
$archived_media_gate$;
reset role;

rollback;
