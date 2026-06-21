# 02 — The Recommended Web Stack (Next.js, mid-2026)

Web-first, also great on iPhone/iPad. Version numbers verified against live npm/docs where
possible; pin to the latest major and confirm patch at install.

## 1. Next.js + React

- **Next.js 16** (released Oct 2025, on the 16.2.x line) + **React 19**. Install
  `next@latest react@latest react-dom@latest`. 16.x is Active LTS; Turbopack is the default
  bundler; Node 20.9+ minimum.
- **Use the App Router.** It's the default and the officially recommended path; every new
  capability (RSC, Server Actions, nested layouts, Partial Pre-Rendering) ships only there.
  Pages Router is effectively maintenance-only.

### RSC vs Client Components for the reader

Server Components are the default; opt into the client only at interactive leaves. The
page-flip engine, Motion, and GSAP all need the DOM, so they live in `"use client"` islands.

- **Server (RSC):** `app/read/[storyId]/page.tsx` fetches the story + pages from Supabase with
  `async/await`, renders the static shell, typography, and **per-route `<head>`/OG metadata**.
  Keeps the heavy content payload out of the JS bundle.
- **Client island:** a thin `PageFlip.tsx` (`"use client"`) that receives server-rendered page
  content as `children`/props and animates it. Passing content as `children` keeps it RSC while
  only the flip logic ships to the browser.
- **Lazy-load the flip engine** with `next/dynamic({ ssr: false })` (required for
  react-pageflip anyway) so it lands in a deferred chunk.

### Hosting

You have Supabase auth and (likely) synced reading progress, so plan for **SSR on Vercel or a
Node host**, not static export. Static `output: 'export'` loses ISR, Server Actions, Route
Handlers, `cookies()`/`headers()`, and built-in image optimization — too limiting once accounts
and progress sync exist. App Router still renders genuinely-static routes statically on its own.

Sources: <https://nextjs.org/blog/next-16> · <https://nextjs.org/support-policy> · <https://nextjs.org/docs/pages/guides/static-exports>

## 2. Tailwind CSS v4 + responsive breakpoints

- **Tailwind v4** (CSS-first; no `tailwind.config.js` by default). Configure in CSS:
  ```css
  @import "tailwindcss";
  @theme {
    --breakpoint-tablet: 744px;     /* optional custom breakpoint */
    --font-display: var(--font-cinzel);
  }
  ```
- Setup: `npm i tailwindcss @tailwindcss/postcss postcss`; `postcss.config.mjs` →
  `{ plugins: { "@tailwindcss/postcss": {} } }`; `@import "tailwindcss";` in `app/globals.css`.
- **Default breakpoints (mobile-first):** `sm` 640 · `md` 768 · `lg` 1024 · `xl` 1280 · `2xl`
  1536. Unprefixed = mobile base; `md:` = that width *and up*. Range targeting via `max-md`,
  `md:max-lg:`, arbitrary `min-[744px]:`.

### Verified iPhone / iPad viewport widths (CSS px) — for media-query design

- **iPhone 14/15/16:** ~390–393px; Pro Max **430–440px** (16 Pro Max 440). All **below `sm`
  (640)** → design phone-first on **base/unprefixed** utilities.
- **iPad portrait:** mini 7 **744px**, standard/Air 11" **820px**, Pro 11" **834px**, 13"
  **1024–1032px**. Landscape: 11" ~1180–1210, 13" ~1366–1376.
- **Practical mapping:** base = iPhone · `md:` (768) = iPad portrait (catches standard/Air/Pro;
  add `--breakpoint-tablet: 744px` if iPad-mini portrait fidelity matters) · `lg:`/`xl:` = iPad
  landscape + desktop.

### Safe-area / notch (required for edge-to-edge reading)

1. `viewport-fit=cover` (without it, all `env(safe-area-inset-*)` resolve to 0). In Next.js:
   `export const viewport = { width: "device-width", initialScale: 1, viewportFit: "cover" }`.
2. `env(safe-area-inset-top/bottom/left/right)` for padding — via Tailwind `@utility`,
   arbitrary values, or the **`tailwindcss-safe-area`** plugin (`pt-safe`, `pb-safe`, `min-h-dvh-safe`).

Sources: <https://tailwindcss.com/blog/tailwindcss-v4> · <https://tailwindcss.com/docs/responsive-design> · <https://www.ios-resolution.com/> · <https://github.com/mvllow/tailwindcss-safe-area>

## 3. Spread vs single-page layout + mobile viewport

- **Switch on orientation + aspect ratio, not a fixed width.** An open book is two portrait
  pages side by side, so the spread only fits in landscape with enough width:
  ```css
  @media (orientation: landscape) and (min-width: 700px) { /* spread */ }
  ```
  Pure aspect-ratio queries (`min-aspect-ratio: 6/5`) work too; most teams add a width floor so
  a small landscape phone doesn't render two tiny pages. This is a refinement of the current
  Flutter 600dp rule — and it's worth being more deliberate than a single pixel threshold.
- **Aspect-ratio-locked book:** CSS `aspect-ratio` (applies only when one dimension is `auto`);
  guard with `max-height: 100dvh`. Pair with `object-fit: cover` for full-bleed illustrations,
  `contain` when nothing can crop.
- **Mobile viewport units:** `svh` (smallest, UI expanded) for must-be-visible controls;
  `lvh` (largest) for immersive art; `dvh` (dynamic) for a surface that tracks the address bar.
  Common pattern: `height: 100dvh` with a `min-height: 100svh` guard. Baseline-widely-available
  as of mid-2025. **This directly fixes the iOS "100vh / address bar" problem Flutter web has.**

Sources: <https://web.dev/blog/viewport-units> · <https://css-tricks.com/full-bleed/> · <https://web.dev/articles/aspect-ratio>

## 4. PWA / installable / fullscreen on iOS & iPad

- Viewport meta: `width=device-width, initial-scale=1, viewport-fit=cover`.
- Apple meta: `apple-mobile-web-app-capable=yes`, `apple-mobile-web-app-status-bar-style=black-translucent`
  (the only way to draw behind the status bar), `apple-touch-icon` 180×180 PNG (WebKit ignores
  SVG/maskable), `apple-mobile-web-app-title`. Set these via Next `metadata.appleWebApp`.
- Manifest: `app/manifest.ts` → `display: 'standalone'` (iOS only honors `browser`/`standalone`),
  name/short_name/start_url/theme_color/icons.
- **iOS limitations to design around:** no install prompt / no `beforeinstallprompt` (must show
  your own "Add to Home Screen" instructions); service workers run but with aggressive cache
  eviction (~50MB, ~7-day) so don't assume offline assets persist; **no reliable background
  audio** (music pauses when backgrounded) — plan playback as foreground-only.

Sources: <https://firt.dev/notes/pwa-ios/> · <https://nextjs.org/docs/app/api-reference/file-conventions/metadata/manifest>

## 5. Audio (background music + narration)

- **Howler.js** (v2.2.4) for narration + SFX: Web Audio with `<audio>` fallback, handles iOS
  gesture-unlock internally, sprites/fades/per-sound volume. **Raw Web Audio** for the seamless
  ambient loop (HTML5 `loop` + MP3 has an audible gap from encoder padding; a decoded
  `AudioBuffer` with `source.loop = true`, or a trimmed OGG/WAV, loops gaplessly).
- **iOS autoplay unlock:** gate first playback behind a real "Tap to start" button; on the
  gesture call `ctx.resume()` + play a 1-sample silent buffer; use `touchend`/`click`. iOS
  re-suspends on backgrounding — re-`resume()` on later interaction / `visibilitychange`. (Our
  Flutter app already follows this gesture-unlock pattern, so the UX carries over.)
- **Per-page narration:** one player; on page change `.stop()` old + `.play()` new, or use an
  audio sprite. For word highlighting, don't drive React state on `timeupdate` — move highlights
  via refs / `requestAnimationFrame` reading `audioContext.currentTime`.

Sources: <https://github.com/goldfire/howler.js/releases> · <https://www.mattmontag.com/web/unlock-web-audio-in-safari-for-ios-and-macos>

## 6. Animation libraries

- **Motion** (formerly Framer Motion; import `motion/react`, v12, React 19 ready) — declarative
  page transitions, `AnimatePresence` enter/exit, swipe-to-turn gestures, spring
  micro-interactions. Mark files `"use client"`.
- **GSAP 3.13** — now **fully free, including all former Club plugins** (SplitText, MorphSVG,
  Flip, ScrollTrigger). Best for a hand-tuned imperative flip timeline or SVG flourishes. The
  old licensing-cost objection is gone.
- **Pairing:** Motion for the React lifecycle/gesture shell; GSAP for bespoke heavy effects.
  Note the page-flip *itself* is handled by react-pageflip — these are for surrounding polish.

Sources: <https://motion.dev/docs/react-upgrade-guide> · <https://gsap.com/blog/3-13/>

## 7. Supabase JS client (backend stays the same)

- First-class: `@supabase/supabase-js` (2.10x) + **`@supabase/ssr`** (the recommended Next.js
  integration; `@supabase/auth-helpers-nextjs` is deprecated).
- `createBrowserClient()` (Client Components) + `createServerClient()` (per request, wired to
  request cookies); a `middleware.ts` runs `updateSession` to refresh tokens.
- **Security:** don't authorize on `getSession()` server-side (spoofable) — use `getClaims()`
  (local JWT verify) or `getUser()`. Base RLS on `app_metadata`, not `user_metadata`.
- **Storage:** public buckets + `getPublicUrl()` for our illustrations/audio (private +
  `createSignedUrl()` if gated); on-the-fly image transforms available on Pro.
- **Gotchas vs the Flutter SDK:** sessions live in **cookies** (re-derived per request), not
  device storage; you handle the OAuth/PKCE callback yourself in `/auth/callback`; don't reuse a
  server client across requests. The **same Supabase project, tables, and edge functions are
  reused unchanged.**

Sources: <https://supabase.com/docs/guides/auth/server-side/nextjs>

## 8. Fonts

`next/font` self-hosts (downloaded at build, served from your domain, zero layout shift).
**Cinzel**, **Cormorant Garamond** (note the underscore: `Cormorant_Garamond`), **Quicksand**
all confirmed available via `next/font/google`. Instantiate in the Root Layout, expose as CSS
variables, map into Tailwind v4 `@theme` (`--font-display`, `--font-serif`, `--font-sans`).

Source: <https://nextjs.org/docs/app/getting-started/fonts>

## Stack summary

| Concern | Pick |
|---|---|
| Framework | Next.js 16 (App Router) + React 19 |
| Styling | Tailwind v4 + `tailwindcss-safe-area` |
| Reader | react-pageflip + StPageFlip (`dynamic`, `ssr:false`) |
| Transitions | Motion (`motion/react`) + optional GSAP 3.13 |
| Audio | Howler.js (narration/SFX) + raw Web Audio (ambient loop) |
| Backend | Supabase `@supabase/supabase-js` + `@supabase/ssr` |
| Fonts | next/font/google self-hosted |
| Responsive | phone = base; iPad portrait = `md:`; spread = `(orientation: landscape) and (min-width: 700px)`; `100dvh` + `100svh` guard |
| Hosting | SSR on Vercel / Node |
