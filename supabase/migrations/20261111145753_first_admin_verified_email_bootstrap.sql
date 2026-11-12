-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: 0746c9bdf0ac656d65b89c045037580d
-- Recovery redaction: replace SET_ADMIN_EMAIL_BEFORE_APPLY with the deployment-specific verified admin email before applying to a new environment.

begin;

create or replace function public.bootstrap_first_admin()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_confirmed_at timestamptz;
  v_updated integer;
begin
  if v_uid is null then
    raise exception 'Bạn cần đăng nhập để kích hoạt tài khoản quản trị.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('tsa-practice-first-admin-bootstrap')
  );

  select u.email, u.email_confirmed_at
    into v_email, v_confirmed_at
  from auth.users u
  where u.id = v_uid;

  if not found
     or lower(coalesce(v_email, '')) <> 'SET_ADMIN_EMAIL_BEFORE_APPLY'
     or v_confirmed_at is null then
    raise exception 'Tài khoản không đúng email quản trị đã đăng ký hoặc email chưa được xác minh.';
  end if;

  if exists (
    select 1 from public.profiles p
    where p.role = 'admin'
  ) then
    raise exception 'Tài khoản Admin đầu tiên đã được thiết lập.';
  end if;

  update public.profiles p
  set role = 'admin',
      updated_at = pg_catalog.now()
  where p.id = v_uid
    and p.status = 'active'
    and p.role = 'student';

  get diagnostics v_updated = row_count;

  if v_updated <> 1 then
    raise exception 'Không tìm thấy hồ sơ học sinh hợp lệ để nâng quyền.';
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Tài khoản Admin đầu tiên đã được kích hoạt.'
  );
end;
$function$;

revoke all on function public.bootstrap_first_admin() from public, anon;
grant execute on function public.bootstrap_first_admin() to authenticated;

commit;
