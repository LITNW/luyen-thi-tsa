-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: undefined

begin;

drop policy if exists profiles_update_own_display_name on public.profiles;
drop policy if exists profiles_admin_update on public.profiles;

create policy profiles_update_own_or_admin
on public.profiles
for update to authenticated
using (
  id = (select auth.uid())
  or (select public.is_admin())
)
with check (
  id = (select auth.uid())
  or (select public.is_admin())
);

commit;
