# Local patches to `turnable_page` (vendored fork)

This is a local copy of `turnable_page` 1.0.0 (pub.dev, author saeedahmed725),
vendored so we can patch the page-flip renderer. Wired up via a path
`dependency_overrides` in `dream_book/pubspec.yaml`.

Keep this file up to date when changing package internals so the fork stays
auditable against upstream.

## Patch 1 — themeable paper / background fill color

**Problem.** The renderer hard-codes a stark white (`0xFFFFFFFF`) fill in several
places used as an anti-flicker backing and for blank/padding leaves:

- the full book-bounds background fill (`paint`)
- the opaque backing drawn behind a page during a flip (`_paintDynamicPage`)
- the injected blank/trailing leaf (`_paintDynamicWhitePage`)
- the blank static page on a single-page (cover) spread (`_drawWhitePageStatic`)

On a cream/dark themed reader this flashes a bright white page (the blank side
of the cover spread) and white wedges along the moving leaf during a flip —
the most jarring artifact in our reader, visible in user bug reports.

**Fix.** Added `FlipSettings.paperColor` (default `0xFFFFFFFF`, so upstream
behavior is unchanged) and routed all four fills through it. The reader passes
the story's page background color, so blank pages and the moving leaf's backing
blend with the spread instead of flashing white. Also dropped the stale
`0xFFE0E0E0` 1px borders the white-page helpers drew (they outlined the fake
white pages — unwanted once the fill matches the paper).

Files:
- `lib/src/flip/flip_settings.dart` — new `paperColor` field (+ ctor/copyWith).
- `lib/src/render/render_turnable_book.dart` — fills use `settings.paperColor`.

### Note on the flip geometry (investigated, NOT a bug)

The flip's coordinate math (`convertToGlobal` / clip path / `_paintDynamicPage`
offsets) was audited against a slow/static-fold probe: settled spreads and the
start/end of flips are geometrically correct. The remaining mid-flip look —
the incoming leaf's text is briefly readable and tilted as it sweeps across — is
inherent to the package rendering the page as a flat 2D-rotated opaque widget
(it never foreshortens to edge-on). That is a rendering-style limitation, not a
coordinate error; addressing it would require a larger change (foreshortening /
stronger depth shadow) and is deliberately out of scope for this patch.
