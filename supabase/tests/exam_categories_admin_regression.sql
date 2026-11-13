-- M2 regression: Admin-managed exam categories and backward-compatible exam assignment.
-- Run only against the disposable CI/local Supabase database.

begin;

do $tests$
declare
  v_admin uuid := '00000000-0000-4000-8000-000000000001';
  v_student uuid := '00000000-0000-4000-8000-000000000003';
  v_parent jsonb;
  v_child jsonb;
  v_inactive jsonb;
  v_parent_id uuid;
  v_child_id uuid;
  v_inactive_id uuid;
  v_exam_id uuid := '64000000-0000-4000-8000-000000000001';
  v_exam_version_id uuid := '64000000-0000-4000-8000-000000000002';
  v_new_exam_id uuid;
  v_save jsonb;
  v_list jsonb;
  v_count integer;
  v_rejected boolean;
begin
  perform set_config('request.jwt.claim.sub',v_admin::text,true);

  if not exists (
    select 1 from public.profiles
    where id=v_admin and role='admin' and status='active'
  ) then
    raise exception 'M2 regression requires the seeded active CI admin.';
  end if;

  insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
  values (
    v_student,'m2-student@example.test',now(),
    '{"display_name":"M2 Student"}'::jsonb
  );

  v_parent := public.admin_save_exam_category(
    'Đề luyện tập','de-luyen-tap',null,'Nhóm đề ôn tập',null,true,1
  );
  v_parent_id := (v_parent->>'id')::uuid;

  v_child := public.admin_save_exam_category(
    'Đề thi thử','de-thi-thu',null,'Đề thi mô phỏng',v_parent_id,true,2
  );
  v_child_id := (v_child->>'id')::uuid;

  v_inactive := public.admin_save_exam_category(
    'Kiểm tra 15 phút','kiem-tra-15-phut',null,'Danh mục đang ẩn',null,false,3
  );
  v_inactive_id := (v_inactive->>'id')::uuid;

  if v_parent_id is null or v_child_id is null or v_inactive_id is null then
    raise exception 'Admin category creation did not return category identities.';
  end if;

  -- Slugs are unique and normalized.
  begin
    perform public.admin_save_exam_category(
      'Trùng slug','de-thi-thu',null,'',null,true,4
    );
    raise exception 'Duplicate category slug was unexpectedly accepted.';
  exception when unique_violation then
    null;
  end;

  -- Hierarchy cannot contain cycles.
  begin
    perform public.admin_save_exam_category(
      'Đề luyện tập','de-luyen-tap',v_parent_id,'Nhóm đề ôn tập',v_child_id,true,1
    );
    raise exception 'Exam category cycle was unexpectedly accepted.';
  exception when check_violation then
    null;
  end;

  -- An active parent cannot be archived while it still has active children.
  begin
    perform public.admin_save_exam_category(
      'Đề luyện tập','de-luyen-tap',v_parent_id,'Nhóm đề ôn tập',null,false,1
    );
    raise exception 'Parent category with active children was unexpectedly archived.';
  exception when check_violation then
    null;
  end;

  -- Legacy exams remain uncategorized unless explicitly assigned.
  insert into public.exams(id,title,description,duration_minutes)
  values (v_exam_id,'M2 category assignment','Disposable CI fixture',30);
  if (select category_id from public.exams where id=v_exam_id) is not null then
    raise exception 'Existing exam default category must remain NULL.';
  end if;

  insert into public.exam_versions(
    id,exam_id,version_no,title,description,duration_minutes,status,created_by
  ) values (
    v_exam_version_id,v_exam_id,1,'M2 category assignment','Disposable CI fixture',30,'draft',v_admin
  );

  if not public.admin_set_exam_category(v_exam_id,v_child_id) then
    raise exception 'Admin category assignment RPC did not report success.';
  end if;
  if (select category_id from public.exams where id=v_exam_id) is distinct from v_child_id then
    raise exception 'Category assignment did not persist on the stable exam identity.';
  end if;

  -- Inactive categories cannot be assigned to exams.
  v_rejected := false;
  begin
    perform public.admin_set_exam_category(v_exam_id,v_inactive_id);
  exception when raise_exception then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Inactive category was unexpectedly assignable.';
  end if;

  -- The category-aware wrapper creates/saves the exam and assigns its category atomically.
  v_save := public.admin_save_exam_content_with_category(
    null,
    'M2 category-aware save',
    'Disposable CI fixture',
    30,
    jsonb_build_array(jsonb_build_object(
      'scope','bank',
      'type','mc',
      'content',jsonb_build_object('q','M2 category wrapper question?','o',jsonb_build_array('A','B')),
      'answer_key',1,
      'explanation','',
      'grading_config','{}'::jsonb,
      'source_metadata','{}'::jsonb,
      'points',1
    )),
    v_child_id,
    false
  );
  v_new_exam_id := (v_save->>'exam_id')::uuid;
  if v_save->>'success' is distinct from 'true'
     or (v_save->>'category_id') is distinct from v_child_id::text
     or (select category_id from public.exams where id=v_new_exam_id) is distinct from v_child_id then
    raise exception 'Category-aware exam save did not persist the category: %',v_save;
  end if;

  v_list := public.admin_list_exam_versions_with_categories();
  if not exists (
    select 1 from jsonb_array_elements(v_list) x(value)
    where value->>'exam_id'=v_new_exam_id::text
      and value->>'category_id'=v_child_id::text
      and value->>'category_name'='Đề thi thử'
  ) then
    raise exception 'Admin exam-version list did not include category metadata.';
  end if;

  -- Soft-archived versions must stay out of the active Admin list, as in the legacy RPC.
  insert into public.exam_versions(
    id,exam_id,version_no,title,description,duration_minutes,status,created_by,archived_at
  ) values (
    '64000000-0000-4000-8000-000000000005',
    v_new_exam_id,99,'Archived fixture version','Must not appear in active list',30,
    'published',v_admin,now()
  );
  v_list := public.admin_list_exam_versions_with_categories();
  if exists (
    select 1 from jsonb_array_elements(v_list) x(value)
    where value->>'exam_version_id'='64000000-0000-4000-8000-000000000005'
  ) then
    raise exception 'Admin category-aware list exposed a soft-archived exam version.';
  end if;

  -- An archived category already assigned to an exam remains preservable when editing that exam.
  perform public.admin_save_exam_category(
    'Đề thi thử','de-thi-thu',v_child_id,'Đề thi mô phỏng',v_parent_id,false,2
  );
  v_save := public.admin_save_exam_content_with_category(
    (v_save->>'exam_version_id')::uuid,
    'M2 category-aware save edited',
    'Disposable CI fixture edited',
    35,
    jsonb_build_array(jsonb_build_object(
      'scope','bank',
      'type','mc',
      'content',jsonb_build_object('q','M2 category wrapper question?','o',jsonb_build_array('A','B')),
      'answer_key',1,
      'explanation','',
      'grading_config','{}'::jsonb,
      'source_metadata','{}'::jsonb,
      'points',1
    )),
    v_child_id,
    false
  );
  if (v_save->>'category_id') is distinct from v_child_id::text
     or (select category_id from public.exams where id=v_new_exam_id) is distinct from v_child_id then
    raise exception 'Editing an exam must preserve its already assigned archived category.';
  end if;

  -- Explicitly selecting "Unclassified" removes an existing assignment.
  v_save := public.admin_save_exam_content_with_category(
    (v_save->>'exam_version_id')::uuid,
    'M2 category-aware save unassigned',
    'Disposable CI fixture unassigned',
    35,
    jsonb_build_array(jsonb_build_object(
      'scope','bank',
      'type','mc',
      'content',jsonb_build_object('q','M2 category wrapper question?','o',jsonb_build_array('A','B')),
      'answer_key',1,
      'explanation','',
      'grading_config','{}'::jsonb,
      'source_metadata','{}'::jsonb,
      'points',1
    )),
    null,
    false
  );
  if v_save->>'category_id' is not null
     or (select category_id from public.exams where id=v_new_exam_id) is not null then
    raise exception 'Explicitly clearing an exam category must persist NULL.';
  end if;

  -- Editing a legacy exam that was never categorized must keep category_id NULL.
  insert into public.exams(id,title,description,duration_minutes)
  values (
    '64000000-0000-4000-8000-000000000003',
    'Legacy uncategorized exam',
    'Pre-existing uncategorized fixture',
    30
  );
  insert into public.exam_versions(
    id,exam_id,version_no,title,description,duration_minutes,status,created_by
  ) values (
    '64000000-0000-4000-8000-000000000004',
    '64000000-0000-4000-8000-000000000003',
    1,'Legacy uncategorized exam','Pre-existing uncategorized fixture',30,'draft',v_admin
  );
  v_save := public.admin_save_exam_content_with_category(
    '64000000-0000-4000-8000-000000000004',
    'Legacy uncategorized exam edited',
    'Legacy fixture edited through wrapper',
    35,
    jsonb_build_array(jsonb_build_object(
      'scope','bank',
      'type','mc',
      'content',jsonb_build_object('q','Legacy uncategorized question?','o',jsonb_build_array('A','B')),
      'answer_key',1,
      'explanation','',
      'grading_config','{}'::jsonb,
      'source_metadata','{}'::jsonb,
      'points',1
    )),
    null,
    false
  );
  if v_save->>'success' is distinct from 'true'
     or v_save->>'category_id' is not null
     or (select category_id from public.exams where id='64000000-0000-4000-8000-000000000003') is not null then
    raise exception 'Editing a legacy uncategorized exam must retain NULL category_id: %',v_save;
  end if;

  -- Admin category list includes inactive rows; student access is limited to active rows.
  if jsonb_array_length(public.admin_list_exam_categories()) <> 3 then
    raise exception 'Admin category list should include active and inactive categories.';
  end if;

  -- Anonymous users cannot execute Admin-only category management functions.
  if has_function_privilege('anon','public.admin_save_exam_category(text,text,uuid,text,uuid,boolean,integer)','EXECUTE')
     or has_function_privilege('anon','public.admin_set_exam_category(uuid,uuid)','EXECUTE') then
    raise exception 'Anonymous role must not execute Admin category functions.';
  end if;
end;
$tests$;

-- Verify RLS with the real authenticated role, first Admin then Student.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $admin_rls$
declare v_count integer;
begin
  select count(*) into v_count from public.exam_categories;
  if v_count <> 3 then
    raise exception 'Admin must see active and inactive categories.';
  end if;
end;
$admin_rls$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',true);
do $student_rls$
declare
  v_count integer;
  v_rejected boolean;
begin
  select count(*) into v_count from public.exam_categories;
  if v_count <> 1 then
    raise exception 'Student direct SELECT must expose only the one remaining active category.';
  end if;

  select count(*) into v_count from public.list_active_exam_categories();
  if v_count <> 1 then
    raise exception 'Active category RPC must return only the one remaining active category.';
  end if;

  update public.exam_categories
  set name='Student attempted rename'
  where slug='de-thi-thu';
  get diagnostics v_count = row_count;
  if v_count <> 0 then
    raise exception 'Student UPDATE of an exam category was unexpectedly accepted.';
  end if;

  delete from public.exam_categories where slug='de-thi-thu';
  get diagnostics v_count = row_count;
  if v_count <> 0 then
    raise exception 'Student DELETE of an exam category was unexpectedly accepted.';
  end if;

  begin
    insert into public.exam_categories(name,slug)
    values ('Student forbidden','student-forbidden');
    raise exception 'Student INSERT into exam_categories was unexpectedly accepted.';
  exception when insufficient_privilege then
    null;
  end;

  v_rejected := false;
  begin
    perform public.admin_save_exam_category(
      'Student forbidden','student-forbidden',null,'',null,true,9
    );
  exception when raise_exception then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Student invoked an Admin category write RPC.';
  end if;
end;
$student_rls$;
reset role;

rollback;
