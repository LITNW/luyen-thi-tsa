-- Allow multiple contextual course offerings to reference one canonical subject.
-- Example: Algebra and Calculus I/II/III may all reference the shared Mathematics subject.
-- Keep a non-unique composite index for context/subject lookups; local_code uniqueness
-- remains enforced independently by education_subjects_context_local_code_uidx.

begin;

drop index if exists public.education_subjects_context_subject_uidx;

create index education_subjects_context_subject_idx
  on public.education_subjects(
    education_level_id,
    coalesce(education_node_id,'00000000-0000-0000-0000-000000000000'::uuid),
    subject_id
  );

commit;
