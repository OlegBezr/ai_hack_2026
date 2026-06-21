# ts_dream_book

Web (React/TypeScript) reimplementation of the Dream Book storytime reader.
Vite + React 19 + Tailwind v4, with the realistic page-flip from a patched,
vendored **StPageFlip**, and a fully **typed Supabase client** generated from the
live schema.

## Run

```bash
npm install
npm run dev        # http://localhost:5181  (and your LAN IP for iPad/iPhone)
```

Requires the local Supabase stack running from the repo root (`supabase start`).
Env lives in `.env.local` (already pointed at the local stack).

```bash
npm run typecheck  # tsc -b --noEmit (app code is strict; vendor is excluded)
npm run lint       # eslint (flat config; ignores vendor + generated types)
npm run build      # tsc -b && vite build
npm run gen:types  # regenerate src/lib/database.types.ts from the local DB
```

## Supabase typing (the important part)

- `src/lib/database.types.ts` — **generated** from the running DB via
  `supabase gen types typescript --local`. Never hand-edit; rerun `gen:types`
  after any schema change.
- `src/lib/supabase.ts` — `createClient<Database>(...)`. Passing the generated
  `Database` type makes every `.from('story')`, column, filter, embedded
  relation, and `.select()` result shape **fully typed and autocompleted**, with
  no hand-written model that can drift.
- `src/features/stories/types.ts` — domain types derived from the generated
  types (`Tables<'story'>`, `Tables<'page'>`), plus the concrete `StoryStyle`
  shape for the `story.style` jsonb column.
- `src/features/stories/queries.ts` — typed queries, e.g. the eager load
  `select('*, page(*)')` with an `order` on the embedded `page` relation — both
  type-checked against the schema.

Note: unauthenticated reads return `permission denied for table story` (RLS
grants SELECT to `authenticated` only). The home screen surfaces this — wiring
`@supabase/ssr`/auth is the next step; until then the reader uses local samples
(`src/features/stories/sample.ts`), shaped exactly like the Supabase payload.

## Page-flip

- `src/vendor/stpageflip/` — **vendored** StPageFlip source carrying two patches
  from `js_books/StPageFlip`:
  1. immediate corner-grab on touch (no 250 ms press-and-hold) — iPad/iPhone fix;
  2. `showPageCorners: false` in use (no hover-fold; flip starts on press/drag).
  Marked `// @ts-nocheck` (third-party; not typechecked by this app).
- `src/components/FlipBook.tsx` — React wrapper. Page content is serialized to
  static HTML and handed to a `createElement` container that **React never
  tracks**, which avoids the React-19-StrictMode-vs-DOM-library conflict.

## Theme

`src/index.css` ports the Flutter "Twilight Storybook" palette + fonts (Cinzel /
Cormorant Garamond / Quicksand) to Tailwind v4 `@theme` tokens.

## Structure

```
src/
  lib/            supabase client + generated DB types
  features/
    stories/      types, typed queries, samples, library home
    reader/       reader screen + route loader
  components/     FlipBook (StPageFlip wrapper), MagicBackground
  vendor/         patched StPageFlip (vendored, @ts-nocheck)
```
