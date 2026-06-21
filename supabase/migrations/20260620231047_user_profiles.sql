-- User profiles: a 1:1 companion row to auth.users holding editable, app-level
-- user data. For now this is just a display `name`, but the table is the home
-- for any future profile fields (avatar, bio, preferences, ...).

-- ─────────────────────────────────────────────────────────────────────────
-- profile
-- ─────────────────────────────────────────────────────────────────────────
create table "public"."profile" (
  "id"         uuid primary key
                 references auth.users (id) on delete cascade,
  "name"       text,                                       -- display name
  "created_at" timestamptz not null default now(),
  "updated_at" timestamptz not null default now(),
  "created_by" uuid references auth.users (id),
  "updated_by" uuid references auth.users (id)
);

comment on table "public"."profile" is
  'Per-user editable profile (1:1 with auth.users), e.g. display name.';

-- ─────────────────────────────────────────────────────────────────────────
-- triggers: updated_at (moddatetime) + who-modified (set_audit_fields)
-- ─────────────────────────────────────────────────────────────────────────
create trigger handle_updated_at
  before update on "public"."profile"
  for each row execute function extensions.moddatetime('updated_at');

create trigger handle_audit_fields
  before insert or update on "public"."profile"
  for each row execute function public.set_audit_fields();

-- ─────────────────────────────────────────────────────────────────────────
-- RLS: a user reads and writes only their own profile row.
-- ─────────────────────────────────────────────────────────────────────────
alter table "public"."profile" enable row level security;

grant select, insert, update, delete on table "public"."profile" to "authenticated";
grant select, insert, update, delete on table "public"."profile" to "service_role";

create policy "Users manage own profile"
  on "public"."profile"
  as permissive for all
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- ─────────────────────────────────────────────────────────────────────────
-- Auto-provision a profile for every new auth user. We extend the existing
-- handle_new_user() trigger fn (which also seeds sample stories) so signup
-- stays a single trigger. Default the display name to the email's local-part.
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_story_1 uuid := extensions.uuid_generate_v4();
  v_story_2 uuid := extensions.uuid_generate_v4();
begin
  -- Profile (auth.uid() is NULL in this trigger context, so stamp audit cols).
  insert into public.profile (id, name, created_by, updated_by)
  values (new.id, split_part(new.email, '@', 1), new.id, new.id);

  -- Story 1
  insert into public.story (id, title, author_id, created_by, updated_by)
  values (v_story_1, 'The Sleepy Little Cloud', new.id, new.id, new.id);

  insert into public.page (story_id, position, text, created_by, updated_by)
  values
    (v_story_1, 0, 'High above the hills lived a little cloud who was always, always sleepy.', new.id, new.id),
    (v_story_1, 1, 'Every morning the sun gently tickled the cloud until it giggled out a soft rain.', new.id, new.id),
    (v_story_1, 2, 'And when night came, the moon tucked the little cloud into a blanket of stars.', new.id, new.id);

  -- Story 2
  insert into public.story (id, title, author_id, created_by, updated_by)
  values (v_story_2, 'Pip the Brave Little Fox', new.id, new.id, new.id);

  insert into public.page (story_id, position, text, created_by, updated_by)
  values
    (v_story_2, 0, 'Deep in the whispering woods lived a tiny fox named Pip with the biggest, fluffiest tail.', new.id, new.id),
    (v_story_2, 1, 'One day Pip set off to find the singing river that the owls always talked about.', new.id, new.id),
    (v_story_2, 2, 'Pip found the river, sang along with it, and skipped home grinning all the way.', new.id, new.id);

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Trigger fn: provisions a profile and seeds 2 sample stories (3 pages each) for a new auth user.';

-- Backfill profiles for any users that predate this table.
insert into public.profile (id, name, created_by, updated_by)
select u.id, split_part(u.email, '@', 1), u.id, u.id
from auth.users u
on conflict (id) do nothing;
