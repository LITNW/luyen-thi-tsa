-- M2 follow-up: preserve an already assigned archived category when editing its exam.
-- Keep the original M2 migration immutable; this migration replaces only the wrapper RPC.

begin;

create or replace function public.admin_save_exam_content_with_category(
  p_exam_version_id uuid,
  p_title text,
  p_description text,
  p_duration_minutes integer,
  p_questions jsonb,
  p_category_id uuid,
  p_publish boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_result jsonb;
  v_exam_id uuid;
  v_locked_category_id uuid;
  v_category_is_active boolean;
  v_existing_category_id uuid;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only an active Admin may save an exam with a category.';
  end if;

  if p_category_id is not null then
    select c.id,c.is_active into v_locked_category_id,v_category_is_active
    from public.exam_categories c
    where c.id=p_category_id
    for share;
    if not found then
      raise exception 'The selected exam category does not exist.';
    end if;

    if p_exam_version_id is not null then
      select e.category_id into v_existing_category_id
      from public.exam_versions ev
      join public.exams e on e.id=ev.exam_id
      where ev.id=p_exam_version_id;
    end if;

    if not v_category_is_active and v_existing_category_id is distinct from p_category_id then
      raise exception 'An inactive category can only be preserved when it is already assigned to this exam.';
    end if;
  end if;

  v_result := public.admin_save_exam_content(
    p_exam_version_id,p_title,p_description,p_duration_minutes,p_questions,p_publish
  );

  v_exam_id := nullif(v_result->>'exam_id','')::uuid;
  if v_exam_id is null then
    raise exception 'Legacy exam save did not return an exam identity.';
  end if;

  update public.exams
  set category_id=p_category_id
  where id=v_exam_id;

  if not found then
    raise exception 'Exam identity was not found after saving the exam.';
  end if;

  return v_result || jsonb_build_object('category_id',p_category_id);
end;
$function$;

revoke all on function public.admin_save_exam_content_with_category(uuid,text,text,integer,jsonb,uuid,boolean) from public,anon;
grant execute on function public.admin_save_exam_content_with_category(uuid,text,text,integer,jsonb,uuid,boolean) to authenticated;

commit;
