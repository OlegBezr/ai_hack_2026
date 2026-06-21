# Local development

How to run the Supabase stack, its edge functions, and the **SvelteKit web app**
(`svelte_dream_book`) locally.

> Looking for the project overview? See [README.md](README.md). For the legacy
> Flutter app setup, see [DEVELOPMENT_LEGACY.md](DEVELOPMENT_LEGACY.md).

## Contents

- [Prerequisites](#prerequisites)
- [Secret files you need](#secret-files-you-need)
- [Running Supabase (database, auth, storage, Studio)](#running-supabase-database-auth-storage-studio)
- [Running the edge functions](#running-the-edge-functions)
- [Seeding the Midjourney key in Vault](#seeding-the-midjourney-key-in-vault)
- [Local auth emails (OTP / magic links)](#local-auth-emails-otp--magic-links)
- [Running the Svelte web app](#running-the-svelte-web-app)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) running (the local stack runs in containers).
- [Supabase CLI](https://supabase.com/docs/guides/local-development) — `brew install supabase/tap/supabase`.
- [Deno 2](https://deno.com/) — `brew install deno` (only for running edge functions or the dev email hook outside the CLI's bundled runtime).
- [Node + pnpm](https://pnpm.io/) — for the Svelte web app.

All `supabase` commands run from the repo root (the `supabase/` directory is auto-detected).

---

## Secret files you need

Everything secret is **git-ignored** — create these by hand. Ask a teammate for the current values.

| File | Purpose | Loaded by |
| --- | --- | --- |
| `supabase/functions/.env` | Secrets injected into edge functions (Deepgram, Anthropic, Sentry; Midjourney lives in Vault) | `supabase start` auto-loads it |
| `svelte_dream_book/.env` | Supabase URL + anon key for the web app | SvelteKit (Vite) |

### `supabase/functions/.env`

```bash
# Deepgram TTS (used by generate-audio)
DEEPGRAM_KEY=<deepgram api key>

# Anthropic / Claude (used by compose-story to split a transcript into pages)
ANTHROPIC_API_KEY=<anthropic api key>   # from https://console.anthropic.com/settings/keys

# Sentry for edge functions (OPTIONAL — unset = full no-op). Use a Sentry "Deno"
# project DSN. Only SENTRY_DSN is required; the rest are optional tuning.
SENTRY_DSN=<sentry deno dsn>
SENTRY_ENVIRONMENT=production
SENTRY_RELEASE=<git sha>
SENTRY_TRACES_SAMPLE_RATE=1.0
```

Notes:

- The Midjourney token set is **not** here — it lives in Supabase Vault (secret
  `midjourney_oauth`), because Midjourney rotates refresh tokens on every refresh
  and the function persists the rotated set there. Seed it separately — see
  [below](#seeding-the-midjourney-key-in-vault).
- `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` are injected
  into functions automatically by the local stack. You only set those when
  deploying to a hosted project.

### `svelte_dream_book/.env`

Copy `svelte_dream_book/.env.example` (already filled with the local stack
values) to `.env`. The anon key is safe in the browser — it only grants
RLS-scoped access.

```bash
PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
PUBLIC_SUPABASE_ANON_KEY=<local anon key from `supabase status`>
```

---

## Running Supabase (database, auth, storage, Studio)

```bash
supabase start
```

Boots Postgres, Auth (GoTrue), Storage, Realtime, the edge runtime, and Studio,
then runs all migrations under `supabase/migrations/` and `supabase/seed.sql`.

Default local ports (from [supabase/config.toml](supabase/config.toml)):

| Service | URL |
| --- | --- |
| API gateway | http://127.0.0.1:54321 |
| Postgres | postgres://postgres:postgres@127.0.0.1:54322/postgres |
| Studio | http://127.0.0.1:54323 |
| Inbucket (email testing) | http://127.0.0.1:54324 |

```bash
supabase status              # re-print local URLs + anon/service_role keys
supabase db reset            # drop, re-run all migrations + reseed (destructive)
supabase stop                # stop the stack (add --no-backup to wipe local data)
```

> `supabase start` already runs the edge functions in its bundled runtime. Serve
> them separately (next section) only for hot reload, live logs, or to debug one.

---

## Running the edge functions

```bash
# Serve every function, auto-loading supabase/functions/.env
supabase functions serve --env-file supabase/functions/.env

# ...or a single function
supabase functions serve generate-illustration --env-file supabase/functions/.env
```

The functions in this repo:

| Function | Path | What it does |
| --- | --- | --- |
| `generate-illustration` | [supabase/functions/generate-illustration/index.ts](supabase/functions/generate-illustration/index.ts) | Calls Midjourney, stamps `page.illustration_url` |
| `generate-audio` | [supabase/functions/generate-audio/index.ts](supabase/functions/generate-audio/index.ts) | Deepgram TTS → uploads MP3 to the `audio` bucket → stamps `page.audio_url` |
| `compose-story` | [supabase/functions/compose-story/index.ts](supabase/functions/compose-story/index.ts) | Claude splits a transcript into a titled, page-by-page story (with per-page art prompts), creates the `story` + `page` rows, returns the prompts |
| `hello-world` | [supabase/functions/hello-world/index.ts](supabase/functions/hello-world/index.ts) | Smoke-test endpoint |

The real functions have `verify_jwt = true`, so calls need a logged-in user's
JWT in the `Authorization` header:

```bash
curl -i http://127.0.0.1:54321/functions/v1/generate-illustration \
  -H "Authorization: Bearer <a-real-user-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"page_id":"<uuid>","prompt":"a misty forest --ar 16:9"}'
```

---

## Seeding the Midjourney key in Vault

Midjourney rotates its refresh token on every refresh (each refresh invalidates
the previous one), so the edge function persists the rotated token set in
**Supabase Vault** under the secret **`midjourney_oauth`**. Access goes through
two `SECURITY DEFINER` wrappers granted to `service_role`,
`public.get_midjourney_oauth()` / `public.set_midjourney_oauth(jsonb)`, created by
[supabase/migrations/20260620231045_midjourney_vault_rotation.sql](supabase/migrations/20260620231045_midjourney_vault_rotation.sql).

**Vault is the only source of truth** — there is no `MJ_*` env fallback. A fresh
project (empty Vault secret) must be seeded once before the first generation. All
three fields are required; `client_id` is the public client you registered with
Midjourney (see [docs/midjourney.md](docs/midjourney.md)):

```sql
select public.set_midjourney_oauth(
  jsonb_build_object(
    'access_token',  '<access token>',
    'refresh_token', '<refresh token>',
    'client_id',     '<client id>',
    'expires_at',    null
  )
);

-- verify
select public.get_midjourney_oauth();
```

Run it from Studio's SQL editor (http://127.0.0.1:54323) or:

```bash
psql "postgres://postgres:postgres@127.0.0.1:54322/postgres" \
  -c "select public.set_midjourney_oauth(jsonb_build_object('access_token','...','refresh_token','...','client_id','...','expires_at',null));"
```

> The `vault` schema isn't exposed over the Data API — never query
> `vault.secrets` from the function directly. See [docs/midjourney.md](docs/midjourney.md)
> for how the shared account, client registration, and token lifetimes work.

---

## Local auth emails (OTP / magic links)

Auth emails are **not** sent locally. Two options:

- **Inbucket** — open http://127.0.0.1:54324 to read any email the stack would send.
- **Console hook** — `[auth.hook.send_email]` in
  [supabase/config.toml](supabase/config.toml) points at a local receiver that
  dumps the OTP to its console:

  ```bash
  deno run --allow-net tools/dev-email-auth-hook/main.ts
  ```

Email confirmations are disabled (`enable_confirmations = false`), so password
sign-in works without this for most flows.

---

## Running the Svelte web app

The [`svelte_dream_book`](svelte_dream_book/) SPA talks to the **same Supabase
project** (DB, auth, RLS, edge functions) — no backend rewrite.

```bash
cd svelte_dream_book
cp .env.example .env   # already filled with local stack values
pnpm install
pnpm dev               # http://localhost:5190
```

The local DB seeds every new user with sample stories — on first launch just
"Enter the library" with any email/password (signup is instant locally).

**Typed Supabase client.** Types are generated from the local stack into
`src/lib/database.types.ts` and fed into `createClient<Database>`
([src/lib/supabase.ts](svelte_dream_book/src/lib/supabase.ts)), so every query is
column-typed. Re-run after any migration that changes the schema:

```bash
pnpm gen:types        # supabase gen types typescript --local > src/lib/database.types.ts
```

Routes: `/` (auth + stories grid), `/read/[id]` (page-flip reader).

---

## Troubleshooting

- **`supabase start` hangs or errors** — make sure Docker is running and ports
  `54321–54327` are free.
- **Functions can't reach Postgres / 500 about service role** — you're running
  `supabase functions serve` without `--env-file`, or the stack isn't started.
  Start the stack first, then serve with the env file.
- **Midjourney calls fail with `invalid_grant`** — the seed refresh token has been
  spent (the shared account is used by Claude Code's MCP and the apps). Get a fresh
  token set and re-seed Vault with `set_midjourney_oauth` (overwrites in place).
- **Midjourney calls fail with `refresh_token / client_id missing from the Vault
  secret`** — the `midjourney_oauth` secret is empty or missing `client_id`. Seed it.
- **Web app shows no stories / 401s** — check `svelte_dream_book/.env` points at
  `http://127.0.0.1:54321` with the current local anon key from `supabase status`.
- **TS errors after a migration** — re-run `pnpm gen:types`.
- **Schema looks stale** — `supabase db reset` re-runs every migration and the seed
  (wipes local data).
