-- Atomic legacy-editor save contract: persist education placement before optional publication.
-- The previous category wrapper remains available for backward compatibility during rollout.

begin;

create or replace function public.admin_save_exam_content_with_education(
  p_exam_version_id uuid,
  p_title text,
  p_description text,
  p_duration_minutes integer,
  p_questions jsonb,
  p_education_subject_id uuid,
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
  v_exam_version_id uuid;
  v_publish_result jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only an active Admin may save an exam with education placement.';
  end if;

  if p_education_subject_id is null then
    raise exception 'An education subject is required before saving an exam.';
  end if;

  -- Save as draft first so the education placement is committed in the same transaction
  -- before the optional publication transition is attempted.
  v_result := public.admin_save_exam_content_with_category(
    p_exam_version_id,
    p_title,
    p_description,
    p_duration_minutes,
    p_questions,
    p_category_id,
    false
  );

  v_exam_id := nullif(v_result->>'exam_id','')::uuid;
  v_exam_version_id := nullif(v_result->>'exam_version_id','')::uuid;

  if v_exam_id is null or v_exam_version_id is null then
    raise exception 'Legacy exam save did not return an exam identity and version.';
  end if;

  perform public.admin_set_exam_education_subject(
    v_exam_id,
    p_education_subject_id
  );

  if coalesce(p_publish,false) then
    v_publish_result := public.admin_publish_exam_version(v_exam_version_id);
  else
    v_publish_result := jsonb_build_object('success',false,'status','draft');
  end if;

  return v_result || jsonb_build_object(
    'education_subject_id',p_education_subject_id,
    'published',coalesce(p_publish,false),
    'publish_result',v_publish_result
  );
end;
$function$;

revoke all on function public.admin_save_exam_content_with_education(uuid,text,text,integer,jsonb,uuid,uuid,boolean) from public,anon;
grant execute on function public.admin_save_exam_content_with_education(uuid,text,text,integer,jsonb,uuid,uuid,boolean) to authenticated;

commit;
