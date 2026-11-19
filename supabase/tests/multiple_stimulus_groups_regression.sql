-- Structural regression for two independent stimulus groups per question.
-- The companion question_media_stimulus_regression.sql verifies two groups end-to-end.

begin;

do $assert$
begin
  if to_regclass('public.question_version_stimuli') is null then
    raise exception 'Normalized question-to-stimulus relation is missing.';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.question_version_stimuli'::regclass) then
    raise exception 'Question-to-stimulus link table must have RLS enabled.';
  end if;
  if not exists (
    select 1 from pg_trigger
    where tgname='question_versions_link_stimulus_groups'
      and tgrelid='public.question_versions'::regclass
      and not tgisinternal
  ) then
    raise exception 'Question version stimulus-link trigger is missing.';
  end if;
  if to_regprocedure('private.lit_link_question_version_stimuli()') is null then
    raise exception 'Question version stimulus-link function is missing.';
  end if;
  if not exists (
    select 1 from pg_proc
    where oid='private.lit_can_read_question_media(text)'::regprocedure
  ) then
    raise exception 'Published student media authorization helper is missing.';
  end if;
end;
$assert$;

rollback;
