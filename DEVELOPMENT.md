# Local development

How to run the Supabase stack and its edge functions locally for this monorepo.

> Looking for the project overview? See [README.md](README.md). This file is
> only about getting a local backend running.

## Contents

- [Local development](#local-development)
  - [Contents](#contents)
  - [Prerequisites](#prerequisites)
  - [Secret files you need](#secret-files-you-need)
    - [`supabase/functions/.env`](#supabasefunctionsenv)
    - [`.env` (repo root)](#env-repo-root)
  - [Running Supabase (database, auth, storage, Studio)](#running-supabase-database-auth-storage-studio)
  - [Running the edge functions](#running-the-edge-functions)
  - [Seeding the Midjourney key in Vault](#seeding-the-midjourney-key-in-vault)
  - [Local auth emails (OTP / magic links)](#local-auth-emails-otp--magic-links)
  - [Pointing the Flutter app at local Supabase](#pointing-the-flutter-app-at-local-supabase)
  - [Troubleshooting](#troubleshooting)

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) running (the local stack runs in containers).
- [Supabase CLI](https://supabase.com/docs/guides/local-development) — `brew install supabase/tap/supabase`.
- [Deno 2](https://deno.com/) (only needed if you run the edge functions or the
  dev email hook outside the CLI's bundled runtime).

All `supabase` commands below are run from the repo root (the `supabase/`
directory is auto-detected).

---

## Secret files you need

Everything secret is **git-ignored** — you must create these by hand. Ask a
teammate for the current values (they are not in the repo).

| File | Purpose | Loaded by | Git-ignored in |
| --- | --- | --- | --- |
| `supabase/functions/.env` | Secrets injected into edge functions (Midjourney + Deepgram) | `supabase start` auto-loads it | `supabase/.gitignore` |
| `dream_book/.env` | Frontend's copy of the Midjourney seed tokens (only if you run the Flutter app against the MCP directly) | Flutter app | `dream_book/.gitignore` |

### `supabase/functions/.env`

This is the important one for the backend. Create it with:

```bash
# Deepgram TTS (used by generate-audio)
DEEPGRAM_KEY=<deepgram api key>
```

Notes:

- These are a **seed**, not a permanent credential. Midjourney rotates refresh
  tokens on every refresh, so the live token set is persisted to Supabase Vault
  after the first refresh (see [below](#seeding-the-midjourney-key-in-vault)).
  The `MJ_*` values are only read when the Vault entry is still empty.
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are
  **not** listed here — the local stack injects them into functions
  automatically. You only set those when deploying to a hosted project.

### `.env` (repo root)

```bash
# .env
BROWSER_BASE_API_KEY=<browserbase key>
```

---

## Running Supabase (database, auth, storage, Studio)

```bash
supabase start
```

This boots Postgres, Auth (GoTrue), Storage, Realtime, the edge runtime, and
Studio, then runs all migrations under `supabase/migrations/` and the
`supabase/seed.sql` seed. On success it prints the local URLs and keys.

Default local ports (from [supabase/config.toml](supabase/config.toml)):

| Service | URL |
| --- | --- |
| API gateway | http://127.0.0.1:54321 |
| Postgres | postgres://postgres:postgres@127.0.0.1:54322/postgres |
| Studio | http://127.0.0.1:54323 |
| Inbucket (email testing) | http://127.0.0.1:54324 |

Useful follow-ups:

```bash
supabase status              # re-print local URLs + anon/service_role keys
supabase db reset            # drop, re-run all migrations + reseed (destructive)
supabase stop                # stop the stack (add --no-backup to wipe local data)
```

> `supabase start` already runs the edge functions inside its bundled edge
> runtime. Run them separately (next section) only when you want hot reload,
> live logs, or to debug a single function.

---

## Running the edge functions

To iterate on functions with hot reload and streamed logs, serve them on their
own (stop relying on the runtime baked into `supabase start`):

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
| `hello-world` | [supabase/functions/hello-world/index.ts](supabase/functions/hello-world/index.ts) | Smoke-test endpoint |

Both real functions have `verify_jwt = true`, so calls need a logged-in user's
JWT in the `Authorization` header. Quick smoke test once the stack is up:

```bash
# Grab the local anon key from `supabase status`
curl -i http://127.0.0.1:54321/functions/v1/generate-illustration \
  -H "Authorization: Bearer <a-real-user-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"page_id":"<uuid>","prompt":"a misty forest --ar 16:9"}'
```

---

## Seeding the Midjourney key in Vault

Midjourney rotates its refresh token on every refresh (each refresh invalidates
the previous one), so the edge function persists the rotated token set in
**Supabase Vault** under a secret named **`midjourney_oauth`**. Access goes
through two `SECURITY DEFINER` wrappers granted to `service_role`,
`public.get_midjourney_oauth()` / `public.set_midjourney_oauth(jsonb)`, created
by [supabase/migrations/20260620231045_midjourney_vault_rotation.sql](supabase/migrations/20260620231045_midjourney_vault_rotation.sql).

**You usually don't have to do anything.** On the first generation, if the Vault
secret is empty, the function falls back to the `MJ_*` values from
`supabase/functions/.env`, refreshes, and writes the rotated set into Vault
automatically. From then on the env seed is ignored.

If you want to seed it explicitly (e.g. you have a known-good token set, or the
env seed has already been spent elsewhere), insert it directly. Connect to local
Postgres and run or do it from supabase studio:

```sql
select public.set_midjourney_oauth(
  jsonb_build_object(
    'access_token',  '<access token>',
    'refresh_token', '<refresh token>',
    'expires_at',    null
  )
);

-- verify
select public.get_midjourney_oauth();
```

You can run this from Studio's SQL editor (http://127.0.0.1:54323) or:

```bash
psql "postgres://postgres:postgres@127.0.0.1:54322/postgres" \
  -c "select public.set_midjourney_oauth(jsonb_build_object('access_token','...','refresh_token','...','expires_at',null));"
```

> The `vault` schema is not exposed over the Data API, which is why the wrappers
> exist — never query `vault.secrets` from the function directly. See
> [docs/midjourney.md](docs/midjourney.md) for how the shared account, client
> registration, and token lifetimes work.

---

## Local auth emails (OTP / magic links)

Auth emails are **not** sent locally. Two options:

- **Inbucket** — open http://127.0.0.1:54324 to read any email the stack would
  have sent.
- **Console hook** — `[auth.hook.send_email]` is enabled in
  [supabase/config.toml](supabase/config.toml), pointing at a small local
  receiver that dumps the OTP to its console. Run it with:

  ```bash
  deno run --allow-net tools/dev-email-auth-hook/main.ts
  ```

  Then watch its output (or the `supabase_edge_runtime_*` Docker logs) for the
  code. Email confirmations are disabled (`enable_confirmations = false`), so
  password sign-in works without this for most flows.

---

## Pointing the Flutter app at local Supabase

If you're running the `dream_book` Flutter app against your local stack, point it
at `http://127.0.0.1:54321` with the local `anon` key from `supabase status`.
The app's own secrets live in `dream_book/.env`. Most backend work doesn't
require the app — use the `curl` smoke test above instead.

---

## Troubleshooting

- **`supabase start` hangs or errors** — make sure Docker is running and ports
  `54321–54327` are free.
- **Functions can't reach Postgres / get a 500 about service role** — you're
  almost certainly running `supabase functions serve` without `--env-file`, or
  the stack isn't started. Start the stack first, then serve with the env file.
- **Midjourney calls fail with `invalid_grant`** — the seed refresh token has
  been spent (the same shared account is used by Claude Code's MCP and the
  Flutter app). Get a fresh token set and re-seed Vault (see above), or update
  `supabase/functions/.env` and clear the `midjourney_oauth` Vault secret so the
  new seed is picked up.
- **Schema looks stale** — `supabase db reset` re-runs every migration and the
  seed from scratch (this wipes local data).
