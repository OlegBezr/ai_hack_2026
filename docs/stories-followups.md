# Stories feature — follow-up questions / notes for review

Small questions and decisions made autonomously while building. Review post-work.

## Decisions made without asking (call out if you disagree)

- **Local-only.** Everything is wired to the local Supabase stack
  (`127.0.0.1:54321`) and the local anon key. Nothing is pushed to the remote
  project. The Supabase URL / anon key are read from `--dart-define` with the
  local values as defaults, so prod can be supplied later without code changes.
- **Sample-story seeding via trigger.** Because `seed.sql` runs on `db reset`
  (before any user exists) and stories need a real `author_id`, sample stories are
  seeded by an `on_auth_user_created` trigger that fires when a new user signs up.
- **Deepgram = TTS only.** The "audio" pipeline uses Deepgram text-to-speech
  (`/v1/speak`) to narrate page text. Speech-to-text wasn't needed for the page
  model, so it's left to the existing demo.
- **Midjourney token handling.** The edge function uses `MJ_ACCESS_TOKEN`, and
  on a 401 attempts a refresh via `MJ_REFRESH_TOKEN` + `MJ_CLIENT_ID`. Refreshed
  tokens live only in function memory (not persisted back to `.env`).

## Known limitation — Midjourney from the edge function (IMPORTANT)

`generate-audio` (Deepgram TTS) is verified end-to-end: generates, uploads to the
`audio` bucket, stamps `page.audio_url`, and the returned URL is browser-reachable
and serves a valid MP3.

`generate-illustration` is implemented identically and correctly, BUT calling
`https://mcp.midjourney.com/mcp` from the Supabase **edge runtime** returns an
HTTP 403 Cloudflare "Just a moment…" JS challenge. Midjourney's endpoint blocks
non-browser / datacenter-IP clients. The existing Flutter demo works because it
calls Midjourney from the user's browser (residential IP). So:
- The server-side illustration pipeline is blocked **in this local environment**.
- Possible fixes to discuss: (a) keep illustration generation client-side like the
  demo; (b) route the edge function's egress through a residential proxy;
  (c) test whether Supabase's production edge IPs are challenged (untested);
  (d) use the Midjourney REST/API product if/when available with a server key.
- The UI handles the failure gracefully (error SnackBar). Audio generation is the
  fully-working server-side example of the pattern.

## Storage public URLs (resolved)

Inside the edge runtime `SUPABASE_URL` is the internal `http://kong:8000`, so
`storage.getPublicUrl()` returned browser-unreachable URLs. Fixed via
`_shared/storage.ts` `publicUrl()` which builds URLs from `SUPABASE_PUBLIC_URL`
(defaults to `http://127.0.0.1:54321` locally; set it to the project URL in prod).

## service_role grants (resolved)

The new Supabase default does not auto-expose new public tables to the Data API
roles. The original schema migration granted `story`/`page` to `authenticated`
only, so the service-role edge functions hit "permission denied". Added migration
`20260620231044_grant_service_role.sql`.

## Open questions

(append as they come up)

- The Midjourney access token in `dream_book/.env` is short-lived (~1h). For a
  long demo we may want a more durable credential or a token-refresh store.
- Should generated illustrations use the full Midjourney grid (4 images) and let
  the user pick, or auto-pick image #1? Currently auto-picks #1.
