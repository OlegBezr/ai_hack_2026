-- Story-level page styling (applies to every page of the story). Replaces the
-- earlier per-page `page.style` approach. This blob carries the text
-- presentation (font, sizing, color, alignment) plus the solid page background
-- color. Empty object == "use defaults".
alter table "public"."story"
  add column "style" jsonb not null default '{}'::jsonb;

comment on column "public"."story"."style" is
  'Story-wide page styling: {fontFamily, fontSizeScale, textColor, backgroundColor, textAlign}. Applies to all pages. Empty = defaults.';

-- Drop the page-texture concept. Page backgrounds are now a solid color from
-- `story.style.backgroundColor` (with preset + custom color selection in the
-- editor). The cover still uses a Midjourney texture (`story.cover_texture`).
alter table "public"."story"
  drop column if exists "page_texture";
