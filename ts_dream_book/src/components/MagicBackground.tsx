import type { ReactNode } from 'react';

/**
 * Full-screen "night sky" backdrop — the indigo→violet gradient plus a soft
 * starfield and a warm candle-gold glow, mirroring the Flutter MagicalBackground.
 */
export function MagicBackground({ children }: { children: ReactNode }) {
  return (
    <div className="relative min-h-full w-full overflow-hidden bg-gradient-to-b from-night-top via-night-mid to-night-bottom">
      {/*
        Decorations live in their own absolutely-positioned, clipped layer. This
        matters: orbs that bleed past the edges must NOT extend the scrollable
        area of the page — otherwise an `overflow-hidden` ancestor becomes
        programmatically scrollable and a child's focus/scrollIntoView (e.g. the
        page-flip engine on a turn) can push the app bar off-screen.
      */}
      <div aria-hidden className="pointer-events-none absolute inset-0 overflow-hidden">
        {/* starfield */}
        <div
          className="animate-twinkle absolute inset-0 opacity-70"
          style={{
            backgroundImage:
              'radial-gradient(1.5px 1.5px at 20% 30%, #fff7, transparent),' +
              'radial-gradient(1.5px 1.5px at 70% 20%, #fff6, transparent),' +
              'radial-gradient(1px 1px at 40% 70%, #fff5, transparent),' +
              'radial-gradient(1.5px 1.5px at 85% 60%, #fff6, transparent),' +
              'radial-gradient(1px 1px at 55% 45%, #fff4, transparent),' +
              'radial-gradient(1px 1px at 15% 80%, #fff5, transparent),' +
              'radial-gradient(1.5px 1.5px at 90% 85%, #fff5, transparent)',
          }}
        />
        {/* warm moon glow */}
        <div
          className="absolute -top-40 left-1/2 h-[28rem] w-[28rem] -translate-x-1/2 rounded-full opacity-30 blur-3xl"
          style={{ background: 'radial-gradient(closest-side, var(--color-gold), transparent)' }}
        />
        {/* lilac haze, top-right */}
        <div
          className="absolute -right-32 top-10 h-80 w-80 rounded-full opacity-20 blur-3xl"
          style={{ background: 'radial-gradient(closest-side, var(--color-lilac), transparent)' }}
        />
        {/* aurora pool, bottom-left */}
        <div
          className="absolute -bottom-40 -left-24 h-96 w-96 rounded-full opacity-10 blur-3xl"
          style={{ background: 'radial-gradient(closest-side, var(--color-aurora), transparent)' }}
        />
      </div>
      <div className="relative z-10">{children}</div>
    </div>
  );
}
