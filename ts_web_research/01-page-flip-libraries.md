# 01 — Page-Flip Libraries for the Web (the core experience)

This is the decisive technical question: can the web reproduce the realistic storybook
page-flip that `turnable_page` gives us in Flutter? **Yes — and with a mature, MIT-licensed,
zero-dependency library that renders live HTML per page.**

## Requirements scorecard

Every option below is graded against what the reader actually needs:

- **(a)** Two-page spread on desktop/tablet
- **(b)** Single-page on phone portrait (auto-switch)
- **(c)** **Dynamic HTML content per page** (live text + images, styled with Tailwind — not
  pre-rendered flat images)
- **(d)** Programmatic next/prev (for our control buttons)
- **(e)** Realistic flip shadow / curl

Requirement **(c)** is the one that eliminates most "flipbook" libraries — many only flip
pre-rendered images or PDF pages, which would force us to rasterize our dynamic, AI-generated,
restyleable story content. We need live DOM pages.

## The winner: react-pageflip + StPageFlip

**`react-pageflip`** (React wrapper) over **`page-flip` / StPageFlip** (engine).

- StPageFlip: <https://github.com/Nodlik/StPageFlip> · npm `page-flip` · demo <https://nodlik.github.io/StPageFlip/>
- react-pageflip: <https://github.com/Nodlik/react-pageflip> · npm `react-pageflip` · demo <https://nodlik.github.io/react-pageflip/>

**Why it wins:**

- **Vanilla TypeScript, zero dependencies, MIT licensed.** No jQuery, no license fees.
- **Renders HTML/CSS pages** (not just images) — curl and shadow are computed geometrically
  and drawn, so it looks physical without a WebGL engine. **This is its standout feature
  and exactly our requirement (c).**
- **Auto-switches to single-page portrait** and fires `onChangeOrientation` — requirement
  (b) handled for us, mirroring our current 600dp adaptive behavior.
- **Soft pages and hard pages** (hard = rigid, good for the cover) — matches our
  `showCover: true` standalone-cover model.
- **Rich imperative API via a ref:** `flipNext()`, `flipPrev()`, `flip(n)`, `turnToPage(n)`,
  `getPageCount()`, `getOrientation()`; events `onFlip`, `onChangeOrientation`, `onChangeState`,
  `onInit`, `onUpdate`.
- **Responsive sizing** via `size="stretch"` + `minWidth/maxWidth/minHeight/maxHeight`.
- Configurable `flippingTime` (our Flutter value is 700ms), `drawShadow`, `useMouseEvents`,
  `mobileScrollSupport`. **Near 1:1 with our current `FlipSettings`.**

**Scorecard: (a) ✅ (b) ✅ (c) ✅ (d) ✅ (e) ✅ — the only option that cleanly hits all five.**

### The two real caveats (both manageable)

1. **Dormant since ~2020.** Last release v2.0.x. Stars: StPageFlip ~800, react-pageflip ~700.
   **Low risk** precisely *because* it has zero dependencies — nothing rots underneath it, and
   the 2025/2026 community roundups still name it the best open-source HTML-content flip engine.
   If it ever needs forking, it's small, MIT, and TypeScript.
2. **Not SSR-safe — must be client-only in Next.js.** It touches `window`/DOM on mount and
   throws during server render. Standard fix:
   ```js
   const HTMLFlipBook = dynamic(() => import('react-pageflip'), { ssr: false })
   ```
   Each page must be a real DOM element (wrap page components with `forwardRef`). This is the
   single biggest integration gotcha — well-documented and routine.

## Full comparison

| Library | License | Deps | HTML pages (c) | Spread (a) | Auto single-page (b) | Prog. control (d) | Curl/shadow (e) | Status | Verdict |
|---|---|---|:---:|:---:|:---:|:---:|:---:|---|---|
| **react-pageflip + StPageFlip** | **MIT** | **none** | ✅ | ✅ | ✅ | ✅ | ✅ | Stable, dormant since 2020 | 🥇 **Use this** |
| Pure CSS 3D transforms | n/a | none | ✅ | ✅ | ✅ | ✅ | ⚠️ flat flip, no curl | DIY | 🥈 Lightweight fallback |
| DearFlip / dflip | **Commercial** ($49/yr–$149) | jQuery-ish | ⚠️ clunky | ✅ | ✅ | ✅ | ✅✅ best realism | Maintained | 🥉 Only if 3D/PDF is the priority |
| Three.js / react-three-fiber curl | varies | heavy | ❌ (texture pipeline) | ✅ | ⚠️ DIY | ✅ | ✅✅✅ | Mostly demos | Bespoke effect only |
| **turn.js** | Dual / commercial, foggy | **jQuery** | ✅ (4th release) | ✅ | ⚠️ manual | ✅ | ✅ | **Abandoned** | ❌ **Avoid** |
| @xata.io/react-flipbook | OSS | light | ❌ image scrubber | ❌ | ❌ | ✅ | ❌ | Maintained | Wrong category |
| PDF flipbook viewers | OSS | react-pdf | ❌ PDF only | ✅ | ✅ | ✅ | ✅ | Maintained | Only for PDF source |

### Notes per option

**turn.js (one of the two you linked) — avoid.**
- `turnjs.com` TLS certificate is currently **expired** — itself a maintenance tell.
- Effectively **abandoned**: ~7.5k stars but 380+ open issues, no releases, no recent commits.
  The good "4th release" (HTML content + hardware accel) was only ever a binary, never
  open-sourced.
- **Requires jQuery**, pinned to old versions (breaks on jQuery 3.x) — a dealbreaker in a
  modern Next.js app.
- **License fog**: source is non-commercial BSD; commercial use needs a paid license. Listed
  in "JS libraries to say goodbye to in 2025."

**page-flip (the other one you linked) — this *is* StPageFlip, the winner.** Good instinct;
the npm package `page-flip` is exactly the engine we recommend, consumed in React via
`react-pageflip`.

**Pure CSS 3D transforms — best lightweight fallback.** `perspective` + `preserve-3d` +
`rotateY()`, with gradient overlays faking shadow. Zero deps, fully SSR-safe, native Tailwind
content, trivial programmatic control. **But** you only get a flat rotate, not a bending/curling
page, and Firefox has known `preserve-3d` z-index bugs. For a kids' storybook where the
page-turn *is* the magic, the fidelity gap is noticeable. Good Plan B if the flip engine ever
becomes a problem.

**DearFlip — most realistic, but commercial + not React-native.** WebGL 3D mode (spiral
binding, true curl, hard covers) is best-in-class. But it's a paid license (Lite is
non-commercial only), HTML-page authoring is awkward vs react-pageflip, and there's no
first-class React component. Choose only if top-tier 3D realism or PDF ingestion becomes a
priority.

**Three.js / react-three-fiber page-curl — max realism, wrong tool here.** A page-curl
*shader* renders to a texture, so live HTML/text per page is impractical (you'd rasterize
each page with html2canvas and lose crisp text + selection + accessibility — the very things
we're migrating to gain). Reserve for a bespoke signature effect with real engineering budget.

## Mapping our Flutter `FlipSettings` → react-pageflip

| Flutter `turnable_page` | react-pageflip equivalent |
|---|---|
| `showCover: true` | `showCover` prop (standalone hard cover) |
| `drawShadow: true` | `drawShadow` prop |
| `flippingTime: 700` | `flippingTime={700}` |
| `PageFlipController.nextPage()/previousPage()` | `ref.current.pageFlip().flipNext()/flipPrev()` |
| 600dp single/spread breakpoint | built-in orientation auto-switch + `onChangeOrientation` |
| Per-page text + illustration leaves | React components as `<HTMLFlipBook>` children (one per leaf), `forwardRef` |

The conceptual model is essentially identical, which makes the reader port low-risk.

## Recommendation

1. **🥇 react-pageflip + StPageFlip (MIT)** — build on this. Hits all five requirements,
   live Tailwind HTML pages, near-1:1 with our current flip model. Caveats: load via
   `dynamic(..., { ssr: false })`, `forwardRef` each page; accept that it's stable-but-dormant.
2. **🥈 Pure CSS 3D transforms** — keep as a lightweight, fully-controlled fallback if you
   ever want zero third-party flip code (accepting flat-flip fidelity).
3. **🥉 DearFlip** — only if you decide best-in-class 3D realism / PDF import is worth a paid,
   non-React integration.

## Sources

- StPageFlip — <https://github.com/Nodlik/StPageFlip> · <https://www.npmjs.com/package/page-flip>
- react-pageflip — <https://github.com/Nodlik/react-pageflip> · <https://nodlik.github.io/react-pageflip/>
- turn.js — <https://github.com/blasten/turn.js> · <https://news.ycombinator.com/item?id=9111481> · <https://thenewstack.io/5-javascript-libraries-you-should-say-goodbye-to-in-2025/>
- DearFlip — <https://dearflip.com/> · <https://js.dearflip.com/>
- Three.js / R3F — <https://github.com/pmndrs/react-three-fiber> · <https://blog.maximeheckel.com/posts/the-study-of-shaders-with-react-three-fiber/>
- Pure CSS — <https://www.cssscript.com/3d-flip-book-animation/> · <https://freefrontend.com/css-book-effects/>
- 2026 roundup — <https://portalzine.de/open-source-page-flip-and-pdf-viewer-solutions-in-javascript-2026/>
