-- Vault-backed store for the shared Midjourney OAuth token set.
--
-- Midjourney rotates refresh tokens (each refresh invalidates the prior one),
-- so the edge function must persist the rotated set somewhere durable. We use
-- Supabase Vault: the token stays encrypted at rest (not in pg_dump/backups).
--
-- The `vault` schema is not exposed to the Data API, so the edge function
-- (service_role, over PostgREST) cannot touch it directly. These two SECURITY
-- DEFINER wrappers — owned by the migration role, which can read/write vault —
-- are the only entry points, and execute is granted to service_role only.
--
-- The secret itself is created out-of-band (Vault entry named 'midjourney_oauth',
-- value = JSON {"access_token","refresh_token"[,"expires_at"]}). set_* will
-- create it on first write if absent, so a fresh project still bootstraps.

-- Read the current token set as jsonb (null when the secret does not exist).
create or replace function public.get_midjourney_oauth()
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select decrypted_secret::jsonb
  from vault.decrypted_secrets
  where name = 'midjourney_oauth';
$$;

comment on function public.get_midjourney_oauth() is
  'Returns the shared Midjourney OAuth token set from Vault. service_role only.';

-- Upsert the token set. Creates the Vault secret on first write, updates in
-- place (re-encrypts, bumps updated_at) thereafter.
create or replace function public.set_midjourney_oauth(tokens jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  select id into v_id from vault.secrets where name = 'midjourney_oauth';
  if v_id is null then
    perform vault.create_secret(
      tokens::text, 'midjourney_oauth', 'Shared Midjourney OAuth tokens'
    );
  else
    perform vault.update_secret(v_id, tokens::text);
  end if;
end;
$$;

comment on function public.set_midjourney_oauth(jsonb) is
  'Upserts the shared Midjourney OAuth token set into Vault. service_role only.';

-- Lock the wrappers down to service_role.
revoke all on function public.get_midjourney_oauth() from public, anon, authenticated;
revoke all on function public.set_midjourney_oauth(jsonb) from public, anon, authenticated;
grant execute on function public.get_midjourney_oauth() to service_role;
grant execute on function public.set_midjourney_oauth(jsonb) to service_role;
