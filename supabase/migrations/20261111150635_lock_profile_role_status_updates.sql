-- Recovered from Supabase Production migration ledger.
-- Original statement MD5: 1e98da901c7012fd26b96040ffd6ca08

begin;

-- Close the self-promotion path: authenticated users may update only display_name.
revoke update (display_name, role, status) on public.profiles from authenticated;
grant update (display_name) on public.profiles to authenticated;

create or replace function public.admin_update_profile(
  p_user_id uuid,
  p_display_name text default null,
  p_role text default null,
  p_status text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_updated integer;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Chỉ Admin mới được quản lý tài khoản.';
  end if;

  if p_display_name is not null
     and (char_length(btrim(p_display_name)) < 1
          or char_length(btrim(p_display_name)) > 80) then
    raise exception 'Tên hiển thị phải có từ 1 đến 80 ký tự.';
  end if;

  if p_role is not null and p_role not in ('student','admin') then
    raise exception 'Vai trò không hợp lệ.';
  end if;

  if p_status is not null and p_status not in ('active','suspended') then
    raise exception 'Trạng thái tài khoản không hợp lệ.';
  end if;

  update public.profiles p
  set display_name = coalesce(btrim(p_display_name), p.display_name),
      role = coalesce(p_role, p.role),
      status = coalesce(p_status, p.status),
      updated_at = pg_catalog.now()
  where p.id = p_user_id;

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'Không tìm thấy tài khoản.';
  end if;

  return jsonb_build_object('success', true, 'user_id', p_user_id);
end;
$function$;

revoke all on function public.admin_update_profile(uuid,text,text,text) from public, anon;
grant execute on function public.admin_update_profile(uuid,text,text,text) to authenticated;

commit;
