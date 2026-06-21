-- Core domain: a story (cover + textures) owns an ordered list of pages,
-- each page being a text + audio + illustration combo.

-- ─────────────────────────────────────────────────────────────────────────
-- story
-- ─────────────────────────────────────────────────────────────────────────
create table "public"."story" (
  "id"            uuid primary key default extensions.uuid_generate_v4(),
  "title"         text not null,
  "cover_texture" text,                                   -- storage url; cover + back of page
  "page_texture"  text,                                   -- storage url; inner pages background
  "author_id"     uuid not null default auth.uid()
                    references auth.users (id) on delete cascade,
  "created_at"    timestamptz not null default now(),
  "updated_at"    timestamptz not null default now(),
  "created_by"    uuid references auth.users (id),
  "updated_by"    uuid references auth.users (id)
);

comment on table "public"."story" is 'A storybook: cover + textures, owned by author_id.';

-- ─────────────────────────────────────────────────────────────────────────
-- page
-- ─────────────────────────────────────────────────────────────────────────
create table "public"."page" (
  "id"               uuid primary key default extensions.uuid_generate_v4(),
  "story_id"         uuid not null references "public"."story" (id) on delete cascade,
  "position"         int  not null,                       -- 0-based order within the book
  "text"             text,
  "audio_url"        text,                                -- storage url
  "illustration_url" text,                                -- storage url
  "created_at"       timestamptz not null default now(),
  "updated_at"       timestamptz not null default now(),
  "created_by"       uuid references auth.users (id),
  "updated_by"       uuid references auth.users (id),
  unique ("story_id", "position")
);

comment on table "public"."page" is 'One page of a story: text + audio + illustration, ordered by position.';

create index "page_story_id_idx" on "public"."page" ("story_id");

-- ─────────────────────────────────────────────────────────────────────────
-- triggers: updated_at (moddatetime) + who-modified (set_audit_fields)
-- ─────────────────────────────────────────────────────────────────────────
create trigger handle_updated_at
  before update on "public"."story"
  for each row execute function extensions.moddatetime('updated_at');

create trigger handle_audit_fields
  before insert or update on "public"."story"
  for each row execute function public.set_audit_fields();

create trigger handle_updated_at
  before update on "public"."page"
  for each row execute function extensions.moddatetime('updated_at');

create trigger handle_audit_fields
  before insert or update on "public"."page"
  for each row execute function public.set_audit_fields();

-- ─────────────────────────────────────────────────────────────────────────
-- RLS: author owns their stories; page access derives from the parent story.
-- ─────────────────────────────────────────────────────────────────────────
alter table "public"."story" enable row level security;
alter table "public"."page"  enable row level security;

grant select, insert, update, delete on table "public"."story" to "authenticated";
grant select, insert, update, delete on table "public"."page"  to "authenticated";

-- story: full CRUD scoped to the owner. (select auth.uid()) is the indexed,
-- planner-friendly form recommended by Supabase.
create policy "Authors manage own stories"
  on "public"."story"
  as permissive for all
  to authenticated
  using ((select auth.uid()) = author_id)
  with check ((select auth.uid()) = author_id);

-- page: allowed when the caller owns the parent story.
create policy "Authors manage pages of own stories"
  on "public"."page"
  as permissive for all
  to authenticated
  using (exists (
    select 1 from "public"."story" s
    where s.id = page.story_id and s.author_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from "public"."story" s
    where s.id = page.story_id and s.author_id = (select auth.uid())
  ));
