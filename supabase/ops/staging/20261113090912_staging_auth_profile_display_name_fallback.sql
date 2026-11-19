-- Evidence copy of the Staging-only signup display-name fallback.
-- Applied in Staging migration ledger as 20261113090912.
-- This file is intentionally outside supabase/migrations and is NOT auto-applied.
-- Do not promote to Production without a separate product/privacy review.

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_display_name text;
begin
  if new.email is null or btrim(new.email) = '' then
    raise exception 'Email đăng ký không hợp lệ';
  end if;

  v_display_name := nullif(
    btrim(new.raw_user_meta_data ->> 'display_name'),
    ''
  );

  if v_display_name is null then
    v_display_name := left(
      coalesce(
        nullif(btrim(split_part(new.email, '@', 1)), ''),
        'Hoc vien'
      ),
      80
    );
  end if;

  if char_length(v_display_name) > 80 then
    raise exception 'Tên hiển thị phải có từ 1 đến 80 ký tự';
  end if;

  insert into public.profiles (
    id,email,user_code,display_name,role,status
  )
  values (
    new.id,new.email,default,v_display_name,'student','active'
  )
  on conflict (id)
  do update set email = excluded.email;

  return new;
end;
$function$;
