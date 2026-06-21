# 05 — Recommendation & Verdict

> **Is rebuilding the storytime reader on the web reasonable, and does it resolve significant
> issues with the current Flutter setup?**
>
> **Yes on both counts — with high confidence.** The web is the right primary target for this
> product, the realistic page-flip is fully achievable with mature MIT libraries, and the move
> fixes structural Flutter-web problems that matter specifically for a *shareable, text-centric
> reading* app. The only real cost (which we were told to ignore) is losing the single codebase
> shared with native mobile.

## Why it's reasonable

1. **The core experience is solved on the web.** The whole risk was "can we reproduce the
   page-flip?" The answer is yes: **react-pageflip + StPageFlip** (MIT, zero-dependency, live
   HTML pages, realistic curl + shadow) maps almost 1:1 onto our current `FlipSettings`. It even
   does the adaptive single-page/spread switch for us. We are *not* trading the magic away.

2. **The backend is reused unchanged.** Supabase (DB, RLS, auth, storage) and the AI edge
   functions (Midjourney, Deepgram) are language-agnostic services. A Next.js client talks to
   the exact same project. The expensive/hard part of the system doesn't move.

3. **Most of the app is portable.** Data models, story styling, fonts, audio, theming — all have
   clean web equivalents (see [`04-feature-parity-map.md`](04-feature-parity-map.md)). The real
   work is the reader UI plus screen volume, not novel engineering.

## Why it resolves significant issues (not just lateral)

Web is the #1 target, and the content is *stories people share*. That is the exact profile
Flutter web is officially weakest at. Migrating delivers structural, officially-corroborated wins:

- **SEO + indexable story text** — Flutter web renders to canvas with no SSR; Google can't
  meaningfully index it. Next.js server-renders real HTML.
- **Working share previews** — Flutter has no per-route `<head>`/OG API and social crawlers
  don't run JS, so shared links are blank. Next.js `generateMetadata` emits OG/Twitter tags into
  server HTML. **For a share-driven storytelling product this is decisive.**
- **Native text UX** — selection, copy, and **browser find-in-page** (which simply doesn't work
  on Flutter canvas text — a real regression for a *reading* app).
- **Robust accessibility** — real semantic HTML always present, vs Flutter's synthetic
  off-by-default semantics tree.
- **iOS Safari** — `dvh`/`svh` + `env(safe-area-inset)` fix the address-bar/100vh and
  full-bleed problems Flutter web still has open; native momentum scroll, keyboard, autofill.
- **Cold load / Lighthouse** — escape the ~1.5MB CanvasKit blank-canvas startup; Next.js
  routinely scores 90–100.

It also **retires two current liabilities**: the fragile unpublished `turnable_page` dependency
(pinned to an old `pdfrx`) and the broken-on-web Rive integration.

See [`03-flutter-web-vs-nextjs.md`](03-flutter-web-vs-nextjs.md) for the full evidence and the
scorecard.

## The honest cost (per your instruction, noted but not weighed)

- **Two codebases** if you keep native iOS/Android Flutter apps alongside the web app.
- **Native ARM mobile performance** is sacrificed *for whatever you move off native* — though
  iPhone/iPad are explicitly secondary here, and a polished responsive PWA covers them well.
- **A rewrite of the client** (not the backend).

## Recommended path

**Web-first Next.js rebuild, with native mobile as an explicit, separate decision.**

Two viable shapes — both endorsed by Flutter's own "split content out of Flutter" guidance:

- **Option A — Full web-first (recommended given web is #1):** Rebuild the entire product as a
  Next.js + Tailwind PWA. iPhone/iPad are served by the responsive PWA. Retire the Flutter web
  build. Keep or sunset the native Flutter apps as a business call — but the web app becomes the
  product. Simplest mental model, single web stack, all the SEO/share wins.

- **Option B — Hybrid:** Next.js becomes the **public web front door** (landing, shareable story
  links with OG previews, SEO, the reader) while Flutter is *retained* for native iOS/iPad where
  you want 60/120fps native feel. More surface to maintain, but keeps native performance and is
  literally what the Flutter team recommends for content-centric surfaces.

Given the stated priorities (web #1; iPhone/iPad "great" but secondary, served via media
queries / PWA), **Option A is the cleaner fit.** Choose B only if a truly native mobile app
remains a first-class product goal.

## Recommended stack (from [`02-web-stack.md`](02-web-stack.md))

Next.js 16 (App Router) + React 19 · Tailwind v4 + `tailwindcss-safe-area` · **react-pageflip +
StPageFlip** for the reader · Motion (+ optional GSAP 3.13) for transitions · Howler.js + raw Web
Audio for sound · Supabase `@supabase/supabase-js` + `@supabase/ssr` · `next/font/google` ·
SSR on Vercel/Node.

## Key risks to plan around (none are blockers)

| Risk | Mitigation |
|---|---|
| react-pageflip dormant since ~2020 | Zero-dependency + MIT; fork-able if ever needed. Pure-CSS 3D flip is a Plan B. |
| react-pageflip not SSR-safe | `dynamic(() => import('react-pageflip'), { ssr: false })`; `forwardRef` each page. |
| Gapless ambient loop | Use a decoded Web Audio `AudioBuffer` (`source.loop`) or trimmed OGG/WAV, not MP3 `loop`. |
| iOS background audio pauses | Platform limit (true in Flutter too); design playback as foreground-only. |
| Cookie auth vs device-storage sessions | `@supabase/ssr` + middleware `updateSession`; handle `/auth/callback` yourself. |
| iOS PWA: no install prompt, cache eviction | Provide manual "Add to Home Screen" UI; re-fetch assets defensively. |

## Bottom line

Rebuilding the storytime reader on the web is **not just reasonable — it's well-aligned with
where this product wants to live.** The page-flip magic survives the move, the backend comes
along for free, and the migration converts the platform's weaknesses (shareability, SEO, text,
iOS web UX) into strengths. Setting dev time aside, **the move resolves real, structural issues
rather than cosmetic ones**, and the recommended stack is mature and well-supported as of 2026.
