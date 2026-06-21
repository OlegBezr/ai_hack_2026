-- Fix set_audit_fields so service-role writes don't wipe updated_by.
--
-- Edge functions stamp page.audio_url / page.illustration_url via the
-- service_role key, where auth.uid() is NULL. The old UPDATE branch did
-- `new.updated_by := auth.uid()` unconditionally, so every asset stamp
-- overwrote the real editor's id with NULL. Coalesce keeps the prior value
-- (or any explicit updated_by the caller supplied) when auth.uid() is NULL.
create or replace function public.set_audit_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (tg_op = 'INSERT') then
    new.created_by := coalesce(new.created_by, auth.uid());
    new.updated_by := coalesce(new.updated_by, auth.uid());
  elsif (tg_op = 'UPDATE') then
    -- never let callers rewrite provenance of the original row
    new.created_by := old.created_by;
    new.updated_by := coalesce(auth.uid(), new.updated_by, old.updated_by);
  end if;
  return new;
end;
$$;
