# 04 — Feature Parity Map (Flutter → Web)

Every current capability mapped to its web equivalent, with a confidence/effort read. This is
the concrete "can we actually rebuild it" checklist.

Legend — **Effort:** 🟢 trivial · 🟡 moderate · 🔴 significant. **Risk:** ✅ low · ⚠️ watch.

## Reader experience

| Flutter (today) | Web equivalent | Effort | Risk |
|---|---|---|---|
| `turnable_page` 2D flip + shadow + curl | **react-pageflip + StPageFlip** | 🟡 | ✅ live HTML pages, MIT, near-1:1 settings |
| `FlipSettings(showCover, drawShadow, flippingTime:700)` | `showCover` / `drawShadow` / `flippingTime={700}` props | 🟢 | ✅ |
| `PageFlipController.next/previousPage()` | `ref.current.pageFlip().flipNext()/flipPrev()` | 🟢 | ✅ |
| 600dp single↔spread adaptive layout | orientation+aspect query (`landscape & min-width:700px`) + library auto-orientation | 🟡 | ✅ refine breakpoint deliberately |
| Single mode: illustration (55%) + scrollable text (45%) | CSS flex/grid page component | 🟢 | ✅ |
| Spread mode: text-left / illustration-right leaves | two React page components per leaf (`forwardRef`) | 🟡 | ✅ |
| Cover page (texture + gradient scrim + glow title) | hard cover page, CSS gradients/`text-shadow` | 🟢 | ✅ |
| Corner-drag + swipe gestures | built into StPageFlip (`mobileScrollSupport`) | 🟢 | ✅ |

## Story content & styling

| Flutter | Web | Effort | Risk |
|---|---|---|---|
| `Story` / `StoryPage` / `StoryStyle` models | TypeScript interfaces (1:1) | 🟢 | ✅ |
| Supabase eager load `select('*, page(*)')` | `supabase-js` identical query | 🟢 | ✅ |
| Per-page font family / size scale / color / align | CSS vars + Tailwind utilities | 🟢 | ✅ |
| Network illustrations (`BoxFit.cover` + placeholder) | `next/image` or `<img>` + `object-fit: cover` + skeleton | 🟢 | ✅ |
| Google Fonts (Cinzel, Cormorant Garamond, Quicksand) | `next/font/google` self-hosted | 🟢 | ✅ |

## Audio

| Flutter | Web | Effort | Risk |
|---|---|---|---|
| `just_audio` looping ambient (3 tracks, vol 0.3, mute) | Howler.js or raw Web Audio | 🟡 | ✅ |
| Gapless `LoopMode.one` | decoded `AudioBuffer` + `source.loop` (avoid MP3 `loop` gap) | 🟡 | ⚠️ use trimmed OGG/WAV or Web Audio buffer |
| Autoplay-safe `ensureStarted()` (tap to unlock) | `ctx.resume()` + silent buffer on first gesture | 🟢 | ✅ pattern already familiar |
| Pause on reader mount / resume on dispose | React `useEffect` mount/unmount | 🟢 | ✅ |
| Per-page Deepgram narration | same `<audio>`/Howler; `.stop()`+`.play()` per page | 🟡 | ✅ |
| **iOS background audio** | not reliable on iOS PWA | — | ⚠️ same limitation, plan foreground-only |

## Backend, auth, AI — reused unchanged

| Flutter | Web | Effort | Risk |
|---|---|---|---|
| Supabase Postgres + RLS | **same project/tables** via `supabase-js` | 🟢 | ✅ |
| Email-OTP auth + passkeys | `@supabase/ssr` (cookie sessions) + `/auth/callback` | 🟡 | ⚠️ cookie model differs from device storage |
| Edge fns: `generate-illustration` / `-texture` / `-audio` | **invoked unchanged** from JS | 🟢 | ✅ no backend rewrite |
| Midjourney / Deepgram | **unchanged** (live in edge fns) | 🟢 | ✅ |
| go_router + auth-redirect guards | Next.js App Router + middleware `updateSession` | 🟡 | ✅ |
| Riverpod state | React state / Zustand / TanStack Query | 🟡 | ✅ |
| Sentry | `@sentry/nextjs` | 🟢 | ✅ |

## Theming / chrome

| Flutter | Web | Effort | Risk |
|---|---|---|---|
| "Twilight Storybook" palette + typography | Tailwind v4 `@theme` tokens | 🟢 | ✅ |
| `MagicScaffold` / `GlassCard` / gradient bg | CSS `backdrop-filter` + gradients | 🟡 | ✅ |
| Music controls UI | React component | 🟢 | ✅ |
| Story editor / list / profile / login screens | React routes | 🔴 | ✅ volume, not difficulty |
| Rive demo (broken on web) | drop, or Lottie/CSS if needed | 🟢 | ✅ removes a current liability |

## Net read

- **No backend rewrite.** The hardest infra — Supabase + AI edge functions — is reused as-is.
- **The reader port is the main engineering**, and react-pageflip makes it tractable with a
  feature set that maps almost 1:1 onto the current `FlipSettings`.
- **The screens are volume, not risk** — straightforward React/Tailwind work.
- A few **watch items**: gapless audio loop (use Web Audio buffer/OGG), cookie-based auth model,
  and iOS background-audio (a platform limit that exists today regardless).
