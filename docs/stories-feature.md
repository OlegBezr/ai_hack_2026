# Stories feature — implementation contract

This document is the shared contract between the Supabase backend (edge functions +
schema) and the Flutter "stories" experience. Both workstreams must conform to it.

## Local environment

- Supabase API:        `http://127.0.0.1:54321`
- Supabase anon key:   `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0`
- Functions base:      `http://127.0.0.1:54321/functions/v1`
- Inbucket (OTP mail): `http://127.0.0.1:54324`
- Flutter SDK:         `~/fvm/default/bin/flutter` (add to PATH)

## Data model (already migrated)

`public.story`: id (uuid pk), title (text), cover_texture (text), page_texture (text),
author_id (uuid -> auth.users), created_at, updated_at, created_by, updated_by.
RLS: authors manage own rows (author_id = auth.uid()).

`public.page`: id (uuid pk), story_id (uuid -> story, cascade), position (int),
text (text), audio_url (text), illustration_url (text), timestamps + audit.
Unique (story_id, position). RLS: authors manage pages of own stories.

Storage buckets (public read, owner-scoped write): `illustrations`, `audio`.
Object path convention: `<uid>/<story_id>/<page_id>.<ext>`.

## Auth

Email + OTP (6-digit code) via Supabase Auth.
- `signInWithOtp(email)` sends the code (visible in Inbucket locally).
- `verifyOTP(email, token, type: OtpType.email)` creates the session.
- New users are auto-created on first OTP (signup enabled). A DB trigger seeds 2
  sample stories with pages for every new user.

## Edge functions (authenticated, verify_jwt = true, CORS-enabled)

All requests carry the Supabase JWT (supabase_flutter's `functions.invoke` adds it).
All responses are JSON. On error: `{ "error": "<message>" }` with a 4xx/5xx status.

### POST /functions/v1/generate-illustration
Request:  `{ "page_id": "<uuid>", "prompt": "<text>" }`
Behavior: verify the page belongs to a story owned by the caller; call Midjourney
`generate_image(prompt)`; download the first grid image; upload to the
`illustrations` bucket at `<uid>/<story_id>/<page_id>.png`; set
`page.illustration_url` to its public URL.
Response: `{ "illustration_url": "<publicUrl>", "job_id": "<id>", "images": ["<url>", ...] }`

### POST /functions/v1/generate-audio
Request:  `{ "page_id": "<uuid>", "text": "<optional override>" }`
Behavior: verify ownership; use `text` (or fall back to `page.text`); call Deepgram
TTS (`/v1/speak`, model `aura-2-thalia-en`, returns MP3); upload to the `audio`
bucket at `<uid>/<story_id>/<page_id>.mp3`; set `page.audio_url`.
Response: `{ "audio_url": "<publicUrl>" }`

Secrets (in `supabase/functions/.env`): `MJ_ACCESS_TOKEN`, `MJ_REFRESH_TOKEN`,
`MJ_CLIENT_ID`, `DEEPGRAM_KEY`. The edge runtime injects `SUPABASE_URL`,
`SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` automatically.

## Flutter data access (direct PostgREST via supabase_flutter, RLS-protected)

- List my stories:        `from('story').select('*, page(*)').order('created_at')`
- Create story:           insert `{ title }` (author_id stamped by trigger/default)
- Update story:           update `{ title, ... }` where id
- Delete story:           delete where id (pages cascade)
- Create page:            insert `{ story_id, position, text }`
- Update page:            update `{ text, position }` where id
- Delete page:            delete where id
- Generate illustration:  `functions.invoke('generate-illustration', body: {...})`
- Generate audio:         `functions.invoke('generate-audio', body: {...})`

## Routes (go_router)

- `/`                application root (existing HomePage with demo cards + new button)
- `/stories/login`  email + OTP login
- `/stories`        list of the user's stories (+ create / delete)
- `/stories/:id`    story editor (title, pages: text, generate illustration/audio)

Redirect: unauthenticated access to `/stories*` (except `/stories/login`) -> login;
authenticated access to `/stories/login` -> `/stories`.
