-- Extensions + shared audit helpers.
-- Convention mirrors atlas_pro: extensions live in the `extensions` schema,
-- `updated_at` is maintained by extensions.moddatetime, and a companion
-- trigger stamps "who modified what" via auth.uid().

create extension if not exists "moddatetime" with schema "extensions";
create extension if not exists "uuid-ossp" with schema "extensions";
create extension if not exists "pgcrypto" with schema "extensions";

-- Stamps created_by on insert and updated_by on every write with the caller's
-- auth uid. Pair this with a moddatetime trigger for the timestamps.
-- security definer so the body can read auth.uid() regardless of the caller's
-- search_path; locked to an empty search_path to avoid hijacking.
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
    new.updated_by := auth.uid();
  end if;
  return new;
end;
$$;

comment on function public.set_audit_fields() is
  'Trigger fn: stamps created_by (insert) and updated_by (insert/update) with auth.uid().';
