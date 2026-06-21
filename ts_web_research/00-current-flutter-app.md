# 00 — The Current Flutter App (what we'd be porting)

A map of the existing `dream_book` Flutter app, focused on the storytime/reading
experience, so the migration discussion is grounded in what actually exists.

## Project shape

```
dream_book/
├── lib/
│   ├── main.dart                       # Entry; Sentry + Supabase init
│   ├── home_page.dart                  # Landing (glass-card UI)
│   ├── stories/
│   │   ├── router.dart                 # go_router (auth redirects, 5 routes)
│   │   ├── supabase_config.dart        # Supabase URL/keys (default = local stack)
│   │   ├── auth/auth_providers.dart    # Riverpod + Supabase email-OTP auth
│   │   ├── screens/
│   │   │   ├── reader_screen.dart       # *** THE READING EXPERIENCE ***
│   │   │   ├── story_editor_screen.dart
│   │   │   ├── stories_list_screen.dart
│   │   │   └── login_screen.dart
│   │   └── data/
│   │       ├── models.dart              # Story / StoryPage / StoryStyle
│   │       └── stories_repository.dart  # Supabase CRUD + edge-fn calls
│   ├── profile/                        # Profile screen + repo
│   ├── audio/background_music.dart      # App-wide looping ambient music
│   ├── theme/                          # "Twilight Storybook" palette + magical widgets
│   ├── deepgram/                       # STT/TTS REST client (+ web/io byte shims)
│   └── demos/                          # turnable_page, rive book, midjourney, deepgram demos
├── web/                                # Flutter web boilerplate + passkeys bundle
├── assets/audio/                       # 3 ambient MP3 tracks + Rive
└── supabase/                           # Local Supabase stack config
```

State management is **Riverpod** (`flutter_riverpod` 3.x). Routing is **go_router** with
auth-redirect guards.

## The reader (the thing that matters most)

`lib/stories/screens/reader_screen.dart` (~538 lines) is built on the **`turnable_page`
package v1.0.0** — an **unpublished / vendored** Flutter package that provides real 2D
page-flip physics (corner-drag, swipe, 3D shadow, curl).

Key behaviors:

- **Adaptive layout at a 600dp breakpoint:**
  - **Single mode (`< 600dp`, phone portrait):** one leaf per page; cover (index 0) then
    content pages stacking illustration (top ~55%) + scrollable text (bottom ~45%).
  - **Spread mode (`>= 600dp`, tablet/web):** classic open book — **text on the left
    leaf, illustration on the right leaf**; cover stands alone, then paired `[text, ill]`
    leaves.
- **Flip engine config:** `FlipSettings(showCover: true, drawShadow: true, flippingTime: 700)`.
  Driven by a `PageFlipController` with `previousPage()` / `nextPage()`; gestures are
  built into the package.
- **Per-page text styling** from `StoryStyle`: font family token, font-size scale on a
  19dp base, hex text color, text alignment, 1.5 line height.
- **Illustrations:** network images (`BoxFit.cover`) with spinner + "No illustration yet"
  placeholder fallback.
- **Music:** background music **pauses on reader mount, resumes on dispose** (silent reading).

### Why the reader is the migration's crux

The whole magic is the **realistic page flip**, and it depends on a **single, unpublished,
pinned package** (`turnable_page` 1.0.0) that itself forces a dependency override on an old
`pdfrx` (2.1.3) PDF engine. That is a fragile, hard-to-maintain core. Any web rebuild lives
or dies on replicating that flip — which is exactly what [`01-page-flip-libraries.md`](01-page-flip-libraries.md)
investigates (and the answer is: the web has a mature, MIT-licensed equivalent).

## Data model

Loaded from **Supabase** (PostgREST, eager `select('*, page(*)')`), RLS-protected per user.

```
Story  { id, title, coverTexture?, style: StoryStyle, authorId?, createdAt?, pages: StoryPage[] }
StoryPage { id, storyId, position, text, audioUrl?, illustrationUrl? }
StoryStyle (JSONB) { fontFamily?, fontSizeScale?, textColor?, backgroundColor?, textAlign? }
```

Tables: `story`, `page`, `profiles`. All content (cover textures, illustrations, audio) is
stored as URLs pointing at Supabase-hosted assets.

## Audio

`lib/audio/background_music.dart` — a Riverpod `Notifier` wrapping a single `just_audio`
player: 3 ambient tracks in `assets/audio/`, `LoopMode.one`, volume 0.3, mute toggle, track
picker. Already has **browser-autoplay-safe** handling (`ensureStarted()` is idempotent;
first user tap unlocks playback). Narration is optional per page via Deepgram TTS
(`aura-2-thalia-en`), STT used only in a demo.

## Backend & AI

- **Supabase**: Postgres + Auth (email-OTP, plus a passkeys bundle) + Storage + Edge Functions.
- **Edge Functions** do the AI generation:
  - `generate-illustration` (Midjourney → per-page illustration URL)
  - `generate-texture` (Midjourney → cover texture URL)
  - `generate-audio` (Deepgram TTS → page audio URL)
- **Deepgram** REST for TTS/STT.

**Crucially: the entire backend is service-based and language-agnostic.** A Next.js app
talks to the exact same Supabase project, the same tables, the same edge functions, with the
official JS SDK. **The backend does not need to be rewritten** — only the client does.

## Platform targeting today

- Builds for iOS, Android, and **Flutter web** (CanvasKit). Web config is minimal
  boilerplate plus a Corbado passkeys bundle.
- Responsiveness is via Flutter `LayoutBuilder`/`MediaQuery` (the 600dp reader breakpoint).

## Known pain points in the current setup

1. **Fragile core dependency** — the page-flip relies on an unpublished `turnable_page`
   1.0.0 pinned to an old `pdfrx`. No maintained Flutter equivalent.
2. **Rive on web** — noted in `main.dart` as blocking the isolate / hanging startup; the
   Rive book demo is effectively disabled on web.
3. **Browser autoplay friction** for music (worked around, but a gesture is still required).
4. **General Flutter-web weaknesses** (SEO, text selection, find-in-page, accessibility,
   iOS Safari scroll/viewport) — detailed in [`03-flutter-web-vs-nextjs.md`](03-flutter-web-vs-nextjs.md).

## What ports cleanly vs. needs rebuilding

| Area | Portability to Next.js |
|---|---|
| Supabase backend (DB, auth, storage, edge fns) | ✅ Unchanged — reuse as-is via JS SDK |
| AI generation (Midjourney, Deepgram) | ✅ Unchanged — same edge functions |
| Data model (Story/Page/Style) | ✅ 1:1 TypeScript types |
| Story styling (font/size/color/align) | ✅ Trivial in CSS/Tailwind |
| Ambient music + per-page narration | ✅ Howler.js / Web Audio (autoplay pattern is well-known) |
| **Page-flip reader** | ⚠️ **Rebuild** — but a mature MIT web library exists (see file 01) |
| Theme / "magical" UI | ⚠️ Rebuild in React/Tailwind (straightforward) |
| Routing + auth guards | ⚠️ Rebuild with Next.js App Router + `@supabase/ssr` middleware |

The takeaway: **most of the app is backend-bound and ports for free; the real engineering
is re-creating the reader UI — and the web has the pieces to do it well.**
