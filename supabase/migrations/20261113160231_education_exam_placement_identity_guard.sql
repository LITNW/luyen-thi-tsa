-- Correct placement identity guard ordering so NULL/unassignment cannot bypass history protection.

begin;

create or replace function public.education_exam_placement_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_offering_active boolean;
  v_level_active boolean;
  v_node_active boolean;
begin
  if tg_op='UPDATE'
     and old.education_subject_id is not null
     and new.education_subject_id is distinct from old.education_subject_id
     and exists (
       select 1 from public.attempts a where a.exam_id=old.id
     ) then
    raise exception using
      errcode = '23514',
      message = 'An exam placement cannot be changed after it has already been classified and has student attempts.';
  end if;

  if new.education_subject_id is null then
    return new;
  end if;

  select es.is_active,l.is_active,
         case when es.education_node_id is null then true else n.is_active end
  into v_offering_active,v_level_active,v_node_active
  from public.education_subjects es
  join public.education_levels l on l.id=es.education_level_id
  left join public.education_nodes n
    on n.id=es.education_node_id
   and n.education_level_id=es.education_level_id
  where es.id=new.education_subject_id;

  if not found then
    raise exception using
      errcode = '23503',
      message = 'The selected education subject offering does not exist.';
  end if;

  if not v_offering_active or not v_level_active or not v_node_active then
    raise exception using
      errcode = '23514',
      message = 'An exam must be assigned to an active education subject offering and active education path.';
  end if;

  return new;
end;
$function$;

commit;
