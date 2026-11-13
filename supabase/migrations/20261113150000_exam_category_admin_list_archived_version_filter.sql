-- M2 follow-up: keep soft-archived exam versions out of the active Admin listing.
-- Preserve the behavior of admin_list_exam_versions() while adding category metadata.

begin;

create or replace function public.admin_list_exam_versions_with_categories()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only an active Admin may list exam versions.';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'exam_id',ev.exam_id,
      'exam_version_id',ev.id,
      'version_no',ev.version_no,
      'title',ev.title,
      'description',ev.description,
      'duration_minutes',ev.duration_minutes,
      'status',ev.status,
      'created_at',ev.created_at,
      'published_at',ev.published_at,
      'question_count',(
        select count(*) from public.exam_version_questions evq
        where evq.exam_version_id=ev.id
      ),
      'attempt_count',(
        select count(*) from public.attempts a
        where a.exam_version_id=ev.id
      ),
      'category_id',e.category_id,
      'category_name',c.name,
      'category_slug',c.slug
    ) order by ev.created_at desc
  ),'[]'::jsonb)
  into v_result
  from public.exam_versions ev
  join public.exams e on e.id=ev.exam_id
  left join public.exam_categories c on c.id=e.category_id
  where ev.archived_at is null;

  return v_result;
end;
$function$;

revoke all on function public.admin_list_exam_versions_with_categories() from public,anon;
grant execute on function public.admin_list_exam_versions_with_categories() to authenticated;

commit;
