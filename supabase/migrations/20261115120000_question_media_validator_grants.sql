-- The manifest validator is a pure function used by authenticated Admin
-- RPCs and BEFORE INSERT triggers. Grant only the signed-in role that needs it.

begin;

revoke all on function public.lit_validate_media_manifest(jsonb) from public,anon;
grant execute on function public.lit_validate_media_manifest(jsonb) to authenticated;

commit;
