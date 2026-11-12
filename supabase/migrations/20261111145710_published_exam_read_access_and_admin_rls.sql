-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: 0926025b8d7636c6f269017460b6d557

-- 005: Published exam read access and admin authoring RLS.
-- Answer keys remain inaccessible to anon/authenticated roles.

begin;

-- Data API table privileges: RLS remains the row-level authorization boundary.
grant select on public.exam_versions,
                public.exam_version_questions,
                public.question_versions
to authenticated;

grant select on public.questions to authenticated;

grant insert, update, delete on public.exam_versions,
                                  public.exam_version_questions,
                                  public.question_versions,
                                  public.questions
to authenticated;

-- Students can see only published exam versions.
drop policy if exists exam_versions_read_published_or_admin on public.exam_versions;
create policy exam_versions_read_published_or_admin
on public.exam_versions
for select to authenticated
using (status = 'published' or (select public.is_admin()));

-- Only admins can create/update/delete exam version records.
drop policy if exists exam_versions_admin_insert on public.exam_versions;
create policy exam_versions_admin_insert
on public.exam_versions for insert to authenticated
with check ((select public.is_admin()));

drop policy if exists exam_versions_admin_update on public.exam_versions;
create policy exam_versions_admin_update
on public.exam_versions for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists exam_versions_admin_delete on public.exam_versions;
create policy exam_versions_admin_delete
on public.exam_versions for delete to authenticated
using ((select public.is_admin()));

-- Students can read only the question ordering/points attached to published versions.
drop policy if exists exam_version_questions_read_published_or_admin on public.exam_version_questions;
create policy exam_version_questions_read_published_or_admin
on public.exam_version_questions
for select to authenticated
using (
  exists (
    select 1
    from public.exam_versions ev
    where ev.id = exam_version_questions.exam_version_id
      and ev.status = 'published'
  )
  or (select public.is_admin())
);

drop policy if exists exam_version_questions_admin_insert on public.exam_version_questions;
create policy exam_version_questions_admin_insert
on public.exam_version_questions for insert to authenticated
with check ((select public.is_admin()));

drop policy if exists exam_version_questions_admin_update on public.exam_version_questions;
create policy exam_version_questions_admin_update
on public.exam_version_questions for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists exam_version_questions_admin_delete on public.exam_version_questions;
create policy exam_version_questions_admin_delete
on public.exam_version_questions for delete to authenticated
using ((select public.is_admin()));

-- Question content is readable only when linked to a published exam version.
drop policy if exists question_versions_read_published_or_admin on public.question_versions;
create policy question_versions_read_published_or_admin
on public.question_versions
for select to authenticated
using (
  exists (
    select 1
    from public.exam_version_questions evq
    join public.exam_versions ev on ev.id = evq.exam_version_id
    where evq.question_version_id = question_versions.id
      and ev.status = 'published'
  )
  or (select public.is_admin())
);

drop policy if exists question_versions_admin_insert on public.question_versions;
create policy question_versions_admin_insert
on public.question_versions for insert to authenticated
with check ((select public.is_admin()));

drop policy if exists question_versions_admin_update on public.question_versions;
create policy question_versions_admin_update
on public.question_versions for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists question_versions_admin_delete on public.question_versions;
create policy question_versions_admin_delete
on public.question_versions for delete to authenticated
using ((select public.is_admin()));

-- Question identities are admin-only; students consume question_versions.
drop policy if exists questions_admin_select on public.questions;
create policy questions_admin_select
on public.questions for select to authenticated
using ((select public.is_admin()));

drop policy if exists questions_admin_insert on public.questions;
create policy questions_admin_insert
on public.questions for insert to authenticated
with check ((select public.is_admin()));

drop policy if exists questions_admin_update on public.questions;
create policy questions_admin_update
on public.questions for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists questions_admin_delete on public.questions;
create policy questions_admin_delete
on public.questions for delete to authenticated
using ((select public.is_admin()));

-- Users may update only their display name; role, status and user_code are not self-editable.
grant update (display_name) on public.profiles to authenticated;
drop policy if exists profiles_update_own_display_name on public.profiles;
create policy profiles_update_own_display_name
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Admins can manage account role/status/display name, but cannot alter email or user_code here.
grant update (display_name, role, status) on public.profiles to authenticated;
drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update
on public.profiles for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

commit;
