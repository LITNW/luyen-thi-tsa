-- Education exam placement and scoped Student catalogue regression.
-- Run after education hierarchy foundation and identity guard migrations.

begin;

do $tests$
declare
  v_admin uuid := '00000000-0000-4000-8000-000000000001';
  v_student uuid := '00000000-0000-4000-8000-000000000004';
  v_thpt uuid;
  v_math uuid;
  v_offer uuid := '66000000-0000-4000-8000-000000000001';
  v_exam uuid := '66000000-0000-4000-8000-000000000002';
  v_published uuid := '66000000-0000-4000-8000-000000000003';
  v_archived uuid := '66000000-0000-4000-8000-000000000004';
  v_rejected boolean;
  v_count integer;
begin
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
  values(v_student,'education-placement-student@example.test',now(),'{"display_name":"Placement Student"}'::jsonb);

  select id into v_thpt from public.education_levels where code='thpt';
  select id into v_math from public.subjects where code='mathematics';

  insert into public.education_subjects(
    id,education_level_id,education_node_id,subject_id,display_name
  ) values(v_offer,v_thpt,null,v_math,'Placement Mathematics');

  insert into public.exams(id,title,description,duration_minutes,created_by)
  values(v_exam,'Education placement fixture','Disposable fixture',30,v_admin);

  if not public.admin_set_exam_education_subject(v_exam,v_offer) then
    raise exception 'Admin placement RPC did not report success.';
  end if;
  if (select education_subject_id from public.exams where id=v_exam) is distinct from v_offer then
    raise exception 'Admin placement RPC did not persist education_subject_id.';
  end if;

  insert into public.exam_versions(
    id,exam_id,version_no,title,description,duration_minutes,status,created_by,published_by,published_at
  ) values(
    v_published,v_exam,1,'Published placement fixture','Published fixture',30,'published',v_admin,v_admin,now()
  );
  insert into public.exam_versions(
    id,exam_id,version_no,title,description,duration_minutes,status,created_by,published_by,published_at,archived_at
  ) values(
    v_archived,v_exam,2,'Archived placement fixture','Archived fixture',30,'published',v_admin,v_admin,now(),now()
  );

  -- Legacy exams can be classified once even if historical attempts exist; once classified, placement is immutable.
  insert into public.attempts(
    id,user_id,exam_id,exam_version_id,answers,score,max_score,elapsed_seconds,result_details,status,started_at,submitted_at,finished_at,last_activity_at
  ) values(
    '66000000-0000-4000-8000-000000000005',
    v_student,v_exam,v_published,'[]'::jsonb,0,1,0,'[]'::jsonb,'submitted',now(),now(),now(),now()
  );

  v_rejected:=false;
  begin
    update public.exams set education_subject_id=null where id=v_exam;
  exception when check_violation then
    v_rejected:=true;
  end;
  if not v_rejected then
    raise exception 'Classified exam with attempts was unexpectedly unassigned.';
  end if;

  perform set_config('request.jwt.claim.sub',v_student::text,true);
  select count(*) into v_count
  from public.list_published_exams_for_education_subject(v_offer);
  if v_count <> 1 then
    raise exception 'Scoped Student catalogue must return exactly the active published version; got %.',v_count;
  end if;

  if has_function_privilege('anon','public.list_published_exams_for_education_subject(uuid)','EXECUTE') then
    raise exception 'Anonymous role must not execute the scoped Student exam catalogue RPC.';
  end if;
  if has_function_privilege('anon','public.admin_set_exam_education_subject(uuid,uuid)','EXECUTE') then
    raise exception 'Anonymous role must not execute the Admin placement RPC.';
  end if;

  v_rejected:=false;
  begin
    perform public.admin_set_exam_education_subject(v_exam,null);
  exception when raise_exception then
    v_rejected:=true;
  end;
  if not v_rejected then
    raise exception 'Student unexpectedly used the Admin placement RPC.';
  end if;
end;
$tests$;

rollback;
