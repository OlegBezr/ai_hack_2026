# TS Web Research — Rebuilding the Storytime Reader on the Web

Research dossier evaluating a move of **Dream Book** (the storytime/reading experience)
from Flutter to a **Next.js + React + Tailwind** web app, with the **web as the #1
target** and **iPhone/iPad as a strong secondary** (responsive, PWA-ish).

This folder is **research only — no implementation**. It exists to answer one question:

> Is rebuilding the reader on the web reasonable, and does it resolve significant
> problems with the current Flutter setup?

**Short answer:** Yes — for the web surface the gains are real and structural, not
cosmetic (SEO/shareability, native text + find-in-page + accessibility, iOS Safari
scroll/viewport/keyboard, cold-load performance). The realistic page-flip experience is
fully achievable on the web today with mature MIT-licensed libraries. The one honest
cost (which we were asked to ignore) is losing the single Flutter codebase shared with
native mobile. See [`05-recommendation.md`](05-recommendation.md) for the verdict.

## Contents

| File | What's inside |
|------|---------------|
| [`00-current-flutter-app.md`](00-current-flutter-app.md) | Map of the existing Flutter app: reader architecture, data model, audio, backend, what's portable. |
| [`01-page-flip-libraries.md`](01-page-flip-libraries.md) | Deep comparison of web page-flip libraries (turn.js, StPageFlip/react-pageflip, DearFlip, Three.js, CSS). The core-experience question. |
| [`02-web-stack.md`](02-web-stack.md) | The full recommended stack: Next.js 16, Tailwind v4, responsive breakpoints for iPhone/iPad, PWA, audio, animation, Supabase, fonts. |
| [`03-flutter-web-vs-nextjs.md`](03-flutter-web-vs-nextjs.md) | Balanced assessment of Flutter web's structural weaknesses vs Next.js — what migrating actually fixes. |
| [`04-feature-parity-map.md`](04-feature-parity-map.md) | Feature-by-feature mapping of every current Flutter capability to its web equivalent. |
| [`05-recommendation.md`](05-recommendation.md) | Final verdict, risks, and the recommended architecture (hybrid vs full rewrite). |

## TL;DR of the stack

| Concern | Pick |
|---|---|
| Framework | **Next.js 16** (App Router) + **React 19** |
| Styling | **Tailwind v4** (CSS-first) + `tailwindcss-safe-area` |
| Reader / page-flip | **`react-pageflip` + StPageFlip** (MIT, dynamic-HTML pages, realistic curl) |
| Transitions / gestures | **Motion** (`motion/react`) + optional **GSAP 3.13** (now fully free) |
| Audio | **Howler.js** (narration/SFX) + raw **Web Audio** (gapless ambient loop) |
| Backend | **Supabase** `@supabase/supabase-js` + `@supabase/ssr` (unchanged backend) |
| Fonts | **next/font/google** self-hosted (Cinzel / Cormorant Garamond / Quicksand) |
| Hosting | **SSR on Vercel / Node** (you have auth + likely synced progress) |

> Research compiled June 2026. Version numbers were verified against live npm/GitHub/docs
> where possible; patch-level numbers are indicative — pin to latest majors and confirm at install.
