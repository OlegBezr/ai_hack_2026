# svelte_dream_book

A SvelteKit + Tailwind v4 web port of the `dream_book` storybook reader, talking
to the **same Supabase project** (DB, auth, RLS, edge functions) as the Flutter
app — no backend rewrite.

## Stack

- **SvelteKit** (SPA mode — `ssr = false`) + **Svelte 5 runes**
- **Tailwind v4** with the "Twilight Storybook" design tokens (ported from the
  Flutter `AppTheme`) in `src/app.css`
- **Typed Supabase client** — `createClient<Database>` over generated types
- **Page-flip reader** — our patched StPageFlip fork, vendored at
  `src/lib/vendor/stpageflip` (immediate touch-drag + no hover-fold)

## Supabase types (the typed client)

Types are generated from the **local** stack into `src/lib/database.types.ts`:

```bash
pnpm gen:types        # supabase gen types typescript --local > src/lib/database.types.ts
```

`src/lib/supabase.ts` feeds that `Database` type into `createClient<Database>`, so
every query (`supabase.from('story').select('*, page(*)')`) is column-typed end
to end. Re-run `pnpm gen:types` whenever a migration changes the schema.

## Run

```bash
cp .env.example .env   # already filled with the local stack values
pnpm install
pnpm dev               # http://localhost:5190  (also exposed on your LAN)
```

The local DB seeds every new user with sample stories, so on first launch just
"Enter the library" with any email/password (signup is instant locally) and
you'll see stories to open.

## Routes

- `/` — auth + stories grid
- `/read/[id]` — the page-flip reader

## Not yet ported (next steps)

Story editor, per-page audio/narration, ambient music, passkeys, and
`@supabase/ssr` cookie auth for an SSR deployment.
