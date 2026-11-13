-- Restrict education catalogue reads to active authenticated profiles.
-- The initial foundation migration is immutable; this follow-up tightens its read policies.

begin;

drop policy education_levels_read_active_or_admin on public.education_levels;
create policy education_levels_read_active_or_admin
on public.education_levels
for select to authenticated
using (
  (
    is_active
    and exists (
      select 1 from public.profiles p
      where p.id=(select auth.uid()) and p.status='active'
    )
  )
  or (select public.is_admin())
);

drop policy education_nodes_read_active_or_admin on public.education_nodes;
create policy education_nodes_read_active_or_admin
on public.education_nodes
for select to authenticated
using (
  (
    is_active
    and exists (
      select 1 from public.profiles p
      where p.id=(select auth.uid()) and p.status='active'
    )
    and exists (
      select 1 from public.education_levels l
      where l.id=education_level_id and l.is_active
    )
  )
  or (select public.is_admin())
);

drop policy education_subjects_read_active_or_admin on public.education_subjects;
create policy education_subjects_read_active_or_admin
on public.education_subjects
for select to authenticated
using (
  (
    is_active
    and exists (
      select 1 from public.profiles p
      where p.id=(select auth.uid()) and p.status='active'
    )
    and exists (
      select 1 from public.education_levels l
      where l.id=education_level_id and l.is_active
    )
    and (
      education_node_id is null
      or exists (
        select 1 from public.education_nodes n
        where n.id=education_node_id
          and n.education_level_id=education_level_id
          and n.is_active
      )
    )
  )
  or (select public.is_admin())
);

commit;
