-- Seed every new auth user with 2 sample stories (3 pages each) so the app has
-- content on first login. Runs as a SECURITY DEFINER trigger on auth.users.
--
-- Notes on the inserts:
--  * author_id is set to NEW.id (the new user).
--  * created_by/updated_by are set explicitly to NEW.id. The page/story audit
--    trigger (public.set_audit_fields) does `coalesce(new.created_by, auth.uid())`;
--    auth.uid() is NULL in this trigger context, so we must supply them.
--  * search_path is locked to '' (security definer hardening), so every object
--    is schema-qualified (public.*, extensions.uuid_generate_v4()).

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
  'Trigger fn: seeds a new auth user with 2 sample stories (3 pages each).';

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
