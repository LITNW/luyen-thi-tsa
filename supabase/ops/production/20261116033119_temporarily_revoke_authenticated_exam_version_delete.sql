-- Evidence copy of the Production-only emergency privilege hotfix.
-- Applied in Production migration ledger as 20261116033119.
-- This file is intentionally outside supabase/migrations and is NOT auto-applied.
-- Preserve the revocation until a separately reviewed access-control decision.

revoke execute on function public.admin_delete_exam_version(uuid) from authenticated;
