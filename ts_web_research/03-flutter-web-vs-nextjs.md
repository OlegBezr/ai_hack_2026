# 03 — Flutter Web vs Next.js: what migrating actually fixes

A balanced assessment (mid-2026) of Flutter web's structural weaknesses against a Next.js
web app, to honestly answer whether moving resolves *real* problems. Citations are to
first-party `docs.flutter.dev`, the Flutter Web FAQ, GitHub issues, and Next.js docs.

## The one-paragraph version

For a product where the **web is the #1 target** and the content is **shareable stories**,
migrating the web surface to Next.js resolves several *structural* Flutter-web problems —
not cosmetic ones. The strongest, officially-corroborated wins are **SEO/shareability** and
**mobile-web text UX**, both of which the Flutter team itself flags as weaknesses. The honest
costs are the loss of a single codebase shared with native mobile, and the fact that Flutter's
canvas pipeline is genuinely *good* at rich animated transitions.

## 1. Rendering: it's all canvas now

The HTML/DOM renderer — the historical escape hatch for SEO and native text — was **removed in
Flutter 3.29** (first 2025 stable). Only two renderers remain, **both paint the UI, including
text, into a `<canvas>`**:

- **CanvasKit** (Skia→WASM, **~1.5MB** added payload) — the default.
- **Skwasm** (compact Skia→WASM, ~1.1MB, multithreaded) — only for `--wasm` builds; needs
  cross-origin isolation + WasmGC, **which iOS Safari historically lacks** — so our #2 platform
  doesn't get the fast path.

Consequences: no native browser text rendering (fonts must be bundled/downloaded), and a
**blank-canvas cold start** (nothing paints until CanvasKit + `main.dart.js` + fonts download
and initialize).

Sources: [renderers](https://docs.flutter.dev/platform-integration/web/renderers) ·
[HTML renderer removal](https://groups.google.com/g/flutter-announce/c/JqkMe7cPkQo) ·
[wasm](https://docs.flutter.dev/platform-integration/web/wasm)

## 2. SEO / shareability — the decisive area for a "stories people share" product

This is where Flutter web is weakest, and the team is bluntly self-critical:

- **Official Flutter Web FAQ:** Flutter web output *"doesn't align with what search engines
  need to properly index,"* and *"Flutter is not suitable for static websites with text-rich
  flow-based content."*
- **Official recommendation:** build content/landing pages in **SEO-optimized HTML or Jaspr**
  and keep Flutter for the app shell only.
- **No native SSR/SSG** — Flutter web is "fundamentally a client-side technology." A CanvasKit
  page is a near-empty HTML shell with no crawlable text, links, or landmarks.
- **Open Graph / social previews are the killer.** There is **no native per-route `<head>`/meta
  API**, and **social crawlers (facebookexternalhit, Twitterbot/X, LinkedInBot, Slackbot,
  WhatsApp/iMessage) don't run JavaScript** — so any client-injected OG tags never appear. A
  shared story link gets no title, no image, no description. The only fix is bolting a
  server-side bot-detection + prerender layer on outside Flutter.

By contrast Next.js emits per-route OG/Twitter tags into **server-rendered HTML** via
`generateMetadata` — its docs explicitly call out HTML-limited bots that can't run JS. For a
share-driven storytelling product, **this alone is a strong reason to migrate the web surface.**

Sources: [Flutter Web FAQ](https://docs.flutter.dev/platform-integration/web/faq) ·
[#86629 no head/meta API](https://github.com/flutter/flutter/issues/86629) ·
[Next.js generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)

## 3. Text & accessibility (this is a *reading* app)

Because text is painted as pixels, not DOM:

- **Text isn't selectable by default** — you opt in with `SelectableText`/`SelectionArea`, and
  web selection has been historically brittle (breaks after context menus, across scroll views).
- **Browser find-in-page (Cmd/Ctrl+F) does not work** on canvas text. For a reading product,
  losing Find is a real regression.
- **Accessibility is a synthetic, bolted-on tree** — Flutter mirrors its Semantics tree into a
  parallel hidden DOM that must stay positionally synced with the canvas, and it's historically
  **off by default for performance** (gated behind an "Enable accessibility" affordance).
- **Focus/keyboard nav is reimplemented** rather than using native DOM tab order.

React/Next.js gets native selection, Find, always-present semantic HTML, and browser-managed
focus **for free**. **Migrating resolves real problems here.**

Sources: [find-in-page #65504](https://github.com/flutter/flutter/issues/65504) ·
[web a11y](https://docs.flutter.dev/ui/accessibility/web-accessibility)

## 4. Mobile-web UX quirks (iOS Safari = our #2 platform)

- **iOS address-bar / dynamic-viewport resize isn't handled** — Flutter's version of the 100vh
  problem, still open as of 2026. Directly hurts a full-bleed reading surface. (On the web, this
  is exactly what `dvh`/`svh` + `env(safe-area-inset)` solve — see [`02-web-stack.md`](02-web-stack.md) §3.)
- **Recurring scroll issues** — single-finger scroll fully broke on iOS 18.2; a scroll-jank
  regression hit 3.29; non-native momentum/overscroll feel is a long-standing complaint.
- **Virtual keyboard** gives no inset on web; **autofill/password managers** can't pre-fill
  (Flutter creates the `<input>` only after focus) — friction for web login.
- **PWA offline is now DIY** — Flutter no longer generates a service worker by default, so
  "download a book for offline reading" is no longer free.

Native DOM handles momentum scroll, the address-bar viewport, keyboard, and autofill natively.
**Migrating resolves real problems here too**, though Flutter does keep patching the regressions.

Sources: [iOS viewport #183596](https://github.com/flutter/flutter/issues/183596) ·
[scroll #158299](https://github.com/flutter/flutter/issues/158299) ·
[autofill #127694](https://github.com/flutter/flutter/issues/127694)

## 5. Load performance & Lighthouse

- **Heavy cold load** — CanvasKit's ~1.5MB sits *before* `main.dart.js` + fonts, all blocking
  first paint. Practitioner reports put Flutter-web TTI at roughly **2–3× optimized JS**
  (directional, not benchmark-grade).
- **Lighthouse often can't even score** Flutter-web performance (canvas), and flags missing
  `lang`/viewport semantics.
- **Next.js routinely hits 90–100** on Performance/SEO/Accessibility with `next/image` + SSG/SSR.
- **Honest counterpoint:** Skwasm/WasmGC is closing the gap by removing the JS bridge — but the
  best path needs modern browsers and lags on iOS Safari.

## 6. When Flutter web *is* recommended

Per the official FAQ: Flutter web is suited to **app-centric experiences — PWAs, SPAs, and
extending existing Flutter mobile apps to web** — and a poor choice for **static, text-rich,
document-centric, SEO-driven content** (split that into HTML/Jaspr). A storybook reader is
*partly* app-centric (the reading interaction) and *partly* content-centric (shareable,
indexable story text) — which is exactly why a clean web rebuild, or a hybrid split, fits.

Source: [Flutter Web FAQ](https://docs.flutter.dev/platform-integration/web/faq)

## 7. What you LOSE by leaving Flutter (being fair)

- **Single codebase across iOS/Android/web** — the biggest real loss. Web→Next.js means two
  stacks (Dart/Flutter mobile + TS/React web). Partly offset by more abundant React/TS talent.
- **Native ARM mobile performance** — Flutter AOT-compiles to native, consistent 60/120fps. For
  iPhone/iPad (secondary but real), dropping native means a separate native path or webview-class
  perf.
- **A full rewrite** — there's no Dart→React converter; UI + state are rebuilt from scratch.
- **Canvas rendering is actually an *advantage* for rich page transitions** — Flutter's
  CustomPainter/Impeller gives pixel-perfect, cross-platform-consistent, high-FPS custom
  animation. (But note: react-pageflip closes most of this gap for *our specific* effect — see
  [`01-page-flip-libraries.md`](01-page-flip-libraries.md).)
- **Hot reload is *not* a meaningful loss** — Flutter hot reload and Next.js Fast Refresh are
  near parity; don't lean on this either way.

## Scorecard: does migrating resolve significant issues?

| Problem | Flutter web | Next.js | Migrating fixes it? |
|---|---|---|---|
| SEO / indexable story text | ❌ canvas, no SSR | ✅ SSR + `generateMetadata` | ✅ **Yes (decisive)** |
| OG / social share previews | ❌ no per-route meta; bots don't run JS | ✅ server HTML meta | ✅ **Yes (decisive)** |
| Text selection / copy | ⚠️ opt-in, brittle | ✅ native | ✅ Yes |
| Browser find-in-page | ❌ doesn't work | ✅ native | ✅ Yes |
| Screen-reader accessibility | ⚠️ synthetic, off by default | ✅ semantic HTML | ✅ Yes |
| iOS address-bar / 100vh | ❌ open issue | ✅ `dvh`/`svh` | ✅ Yes |
| iOS momentum scroll / jank | ⚠️ recurring regressions | ✅ native | ✅ Yes |
| Web login autofill | ⚠️ broken | ✅ native | ✅ Yes |
| Cold load / Lighthouse | ⚠️ ~1.5MB+ canvas, TTI 2–3× | ✅ 90–100 | ✅ Yes |
| Realistic page-flip | ✅ `turnable_page` (fragile dep) | ✅ react-pageflip | ↔ Parity |
| One codebase w/ native mobile | ✅ | ❌ | ❌ **Lost** |
| Native mobile 60/120fps | ✅ | ⚠️ web on mobile | ❌ Lost (for native) |

## Conclusion

**Yes — for the web surface, migrating to Next.js resolves significant, structural Flutter-web
problems** that matter specifically for a public, shareable, text-centric reading product: SEO,
share previews, find-in-page, native text + accessibility, iOS Safari scroll/viewport, and
cold-load. These are officially corroborated, not marginal.

The honest framing is that the *only* real thing you trade away (setting dev cost aside) is the
**single codebase shared with native mobile** — which points toward either a clean web-first
rebuild or a **hybrid** (Next.js for web, Flutter retained for native iOS/iPad). See
[`05-recommendation.md`](05-recommendation.md).
