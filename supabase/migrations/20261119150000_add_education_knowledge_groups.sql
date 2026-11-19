-- Add a first-class knowledge-group classification to course offerings.
-- General-science, political-theory, and language/skills courses are independent of majors.
-- Major-foundation and specialization offerings must point to a major node.
-- Existing offerings remain valid and are initially marked unclassified.

begin;

alter table public.education_subjects
  add column knowledge_group text not null default 'unclassified'
  check (knowledge_group in (
    'general_sciences',
    'political_theory',
    'major_foundation',
    'specialization',
    'languages_skills',
    'unclassified'
  ));

create index education_subjects_level_group_active_idx
  on public.education_subjects(education_level_id,knowledge_group,is_active,display_order);

create or replace function public.education_subjects_knowledge_group_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_node_type text;
begin
  if new.knowledge_group in ('general_sciences','political_theory','languages_skills')
     and new.education_node_id is not null then
    raise exception using
      errcode = '23514',
      message = 'This knowledge group is independent of a major and must not reference an education node.';
  end if;

  if new.knowledge_group in ('major_foundation','specialization') then
    if new.education_node_id is null then
      raise exception using
        errcode = '23514',
        message = 'Major-foundation and specialization offerings require a major.';
    end if;

    select node_type into v_node_type
    from public.education_nodes
    where id=new.education_node_id
      and education_level_id=new.education_level_id;

    if v_node_type is distinct from 'major' then
      raise exception using
        errcode = '23514',
        message = 'Major-foundation and specialization offerings must reference a major node.';
    end if;
  end if;

  return new;
end;
$function$;

create trigger education_subjects_knowledge_group_guard
before insert or update of education_level_id,education_node_id,knowledge_group
on public.education_subjects
for each row execute function public.education_subjects_knowledge_group_guard();

commit;
