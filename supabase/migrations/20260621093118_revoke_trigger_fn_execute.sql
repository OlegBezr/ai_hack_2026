-- Revoke RPC access to trigger-only SECURITY DEFINER functions.
--
-- handle_new_user() and set_audit_fields() are trigger functions; they should
-- not be callable via the PostgREST /rest/v1/rpc API. Triggers continue to fire
-- regardless of these grants (they run as the table owner), so revoking EXECUTE
-- from API roles closes the exposure without affecting behavior.
-- Fixes security advisors 0028 / 0029.

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.set_audit_fields() FROM anon, authenticated, public;
