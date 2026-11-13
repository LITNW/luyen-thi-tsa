-- Education hierarchy foundation regression.
-- Run only against disposable CI/local database after the foundation migration.

begin;

do $tests$
declare
  v_admin uuid := '00000000-0000-4000-8000-000000000001';
  v_student uuid := '00000000-0000-4000-8000-000000000002';
  v_thpt uuid;
  v_uni uuid;
  v_grade uuid := '65000000-0000-4000-8000-000000000001';
  v_institution uuid := '65000000-0000-4000-8000-000000000002';
  v_program uuid := '65000000-0000-4000-8000-000000000003';
  v_major uuid := '65000000-0000-4000-8000-000000000004';
  v_math uuid;
  v_offer uuid := '65000000-0000-4000-8000-000000000005';
  v_university_offer uuid := '65000000-0000-4000-8000-000000000006';
  v_exam uuid := '65000000-0000-4000-8000-000000000007';
  v_rejected boolean;
begin
  perform set_config('request.jwt.claim.sub',v_admin::text,true);

  select id into v_thpt from public.education_levels where code='thpt';
  select id into v_uni from public.education_levels where code='university';
  select id into v_math from public.subjects where code='mathematics';

  if v_thpt is null or v_uni is null or v_math is null then
    raise exception 'Expected education levels or canonical Mathematics subject were not seeded.';
  end if;

  if (select count(*) from public.education_levels where code in ('thpt','university')) <> 2 then
    raise exception 'Education level seeds must be idempotent and unique.';
  end if;

  -- THPT can use a direct level -> subject -> exam path (node is NULL).
  insert into public.education_subjects(
    id,education_level_id,education_node_id,subject_id,local_code,display_name
  ) values (
    v_offer,v_thpt,null,v_math,'MATH-THPT','Toán'
  );

  -- University can use optional institution -> program -> major context nodes.
  insert into public.education_nodes(
    id,education_level_id,parent_id,node_type,code,name
  ) values (
    v_institution,v_uni,null,'institution','hust','Đại học Bách khoa Hà Nội'
  );
  insert into public.education_nodes(
    id,education_level_id,parent_id,node_type,code,name
  ) values (
    v_program,v_uni,v_institution,'program','engineering','Chương trình kỹ thuật'
  );
  insert into public.education_nodes(
    id,education_level_id,parent_id,node_type,code,name
  ) values (
    v_major,v_uni,v_program,'major','mechanical','Kỹ thuật cơ khí'
  );
  insert into public.education_subjects(
    id,education_level_id,education_node_id,subject_id,local_code,display_name
  ) values (
    v_university_offer,v_uni,v_major,v_math,'ME-CALC-1','Giải tích 1'
  );

  -- A grade node is also valid as a top-level THPT context.
  insert into public.education_nodes(
    id,education_level_id,parent_id,node_type,code,name
  ) values (
    v_grade,v_thpt,null,'grade','grade-12','Lớp 12'
  );

  -- Same-level composite FK rejects a parent from another education level.
  v_rejected := false;
  begin
    insert into public.education_nodes(
      education_level_id,parent_id,node_type,code,name
    ) values (
      v_thpt,v_institution,'custom','cross-level','Invalid cross-level parent'
    );
  exception when foreign_key_violation then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Cross-level parent reference was unexpectedly accepted.';
  end if;

  -- A grade cannot be nested under an institution; invalid node semantics are rejected.
  v_rejected := false;
  begin
    insert into public.education_nodes(
      education_level_id,parent_id,node_type,code,name
    ) values (
      v_uni,v_institution,'grade','invalid-grade','Invalid nested grade'
    );
  exception when check_violation then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Invalid grade hierarchy was unexpectedly accepted.';
  end if;

  -- Cycle guard.
  v_rejected := false;
  begin
    update public.education_nodes set parent_id=v_major where id=v_institution;
  exception when check_violation then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Education hierarchy cycle was unexpectedly accepted.';
  end if;

  -- An active parent cannot be deactivated while it has active descendants.
  v_rejected := false;
  begin
    update public.education_nodes set is_active=false where id=v_institution;
  exception when check_violation then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Parent with active descendants was unexpectedly deactivated.';
  end if;

  -- Subject offering cannot be active under an inactive node.
  update public.education_nodes set is_active=false where id=v_major;
  v_rejected := false;
  begin
    update public.education_subjects set is_active=false where id=v_university_offer;
    update public.education_subjects set is_active=true where id=v_university_offer;
  exception when check_violation then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'An active offering under an inactive node was unexpectedly accepted.';
  end if;

  -- Existing exam identities remain unplaced by default and are not rewritten by the migration.
  insert into public.exams(id,title,description,duration_minutes,created_by)
  values (v_exam,'Education hierarchy regression','Disposable fixture',30,v_admin);
  if (select education_subject_id from public.exams where id=v_exam) is not null then
    raise exception 'New exam must remain unplaced until explicitly assigned.';
  end if;

  update public.exams set education_subject_id=v_offer where id=v_exam;
  if (select education_subject_id from public.exams where id=v_exam) is distinct from v_offer then
    raise exception 'Education subject offering assignment did not persist.';
  end if;

  -- Student can read active levels but cannot mutate the catalogue.
  perform set_config('request.jwt.claim.sub',v_student::text,true);
  if (select count(*) from public.education_levels where is_active) < 2 then
    raise exception 'Authenticated student could not read active education levels.';
  end if;
end;
$tests$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);

do $rls$
begin
  if has_table_privilege('anon','public.education_levels','SELECT') then
    raise exception 'anon must not have direct SELECT on education_levels.';
  end if;

  begin
    insert into public.education_levels(code,name)
    values ('student_insert','Student insert');
    raise exception 'Student unexpectedly inserted an education level.';
  exception when insufficient_privilege then
    null;
  end;
end;
$rls$;

rollback;
