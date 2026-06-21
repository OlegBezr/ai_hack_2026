import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { MagicScaffold } from '../../components/MagicScaffold';
import { IconButton, Spinner } from '../../components/ui';
import { FlipBook, type FlipBookHandle, type FlipPage } from '../../components/FlipBook';
import { useBackgroundMusic } from '../audio/BackgroundMusic';
import { usePageNarration } from '../audio/usePageNarration';
import { BASE_PROSE_PX, fontFamilyCss, resolveStyle, type StoryWithPages, type PageRow } from '../stories/types';

/** Below this width we render one page at a time; at/above it, an open spread. */
const SPREAD_BREAKPOINT = 600;
const WARM_COVER = '#8d5524';

type ReaderMode = 'single' | 'spread';

type ResolvedStyle = ReturnType<typeof resolveStyle>;

/* ── Static page faces (serialized to HTML by FlipBook; no handlers/hooks) ── */

function proseStyle(s: ResolvedStyle): React.CSSProperties {
  return {
    fontFamily: fontFamilyCss(s.fontFamily),
    fontSize: BASE_PROSE_PX * s.fontSizeScale,
    lineHeight: 1.5,
    color: s.textColor,
    textAlign: s.textAlign,
    whiteSpace: 'pre-wrap',
  };
}

/**
 * Front/back cover face. The front shows the title; the back reuses the same
 * texture with no text so the book can be closed at the end.
 */
function CoverFace({ story, showTitle = true }: { story: StoryWithPages; showTitle?: boolean }) {
  const texture = story.cover_texture;
  return (
    <div
      className="flex h-full w-full items-center justify-center bg-cover bg-center text-center"
      style={{
        backgroundColor: WARM_COVER,
        backgroundImage: texture ? `url("${texture}")` : undefined,
      }}
    >
      <div
        className="flex h-full w-full items-center justify-center p-8"
        style={{
          background:
            'linear-gradient(to bottom, rgba(0,0,0,0.54) 0%, rgba(0,0,0,0) 45%, rgba(0,0,0,0.87) 100%)',
        }}
      >
        {showTitle && (
          <h2
            className="font-display font-bold text-white"
            style={{
              fontSize: 'clamp(28px, 6vw, 44px)',
              textShadow:
                '0 2px 12px rgba(0,0,0,0.9), 0 0 24px color-mix(in srgb, var(--color-gold) 50%, transparent)',
            }}
          >
            {story.title}
          </h2>
        )}
      </div>
    </div>
  );
}

function Illustration({ url, bg }: { url: string | null; bg: string }) {
  if (url) {
    return (
      <img src={url} alt="" className="h-full w-full object-cover" style={{ backgroundColor: bg }} />
    );
  }
  return (
    <div
      className="flex h-full w-full flex-col items-center justify-center gap-2"
      style={{ backgroundColor: bg }}
    >
      <span className="text-5xl text-black/20">🖼️</span>
      <span className="text-black/40">No illustration yet</span>
    </div>
  );
}

/** SINGLE mode — illustration on top (~55%), text below (~45%). */
function SingleFace({ page, style }: { page: PageRow; style: ResolvedStyle }) {
  return (
    <div className="flex h-full w-full flex-col" style={{ backgroundColor: style.backgroundColor }}>
      <div style={{ flex: '55 1 0%' }}>
        <Illustration url={page.illustration_url} bg={style.backgroundColor} />
      </div>
      <div className="thin-scroll overflow-auto" style={{ flex: '45 1 0%', padding: '24px 28px 28px' }}>
        <p style={proseStyle(style)}>{page.text ?? ''}</p>
      </div>
    </div>
  );
}

/** SPREAD mode — text fills the left leaf, vertically centered. */
function TextFace({ page, style }: { page: PageRow; style: ResolvedStyle }) {
  return (
    <div
      className="thin-scroll h-full w-full overflow-auto"
      style={{ backgroundColor: style.backgroundColor, padding: '48px 40px' }}
    >
      {/* min-h-full + justify-center keeps short pages vertically centered while
          long ones still scroll from the top instead of clipping. */}
      <div className="flex min-h-full flex-col justify-center">
        <p style={proseStyle(style)}>{page.text ?? ''}</p>
      </div>
    </div>
  );
}

/* ─────────────────────────── Reader screen ─────────────────────────── */

export function ReaderScreen({ story }: { story: StoryWithPages }) {
  const navigate = useNavigate();
  const music = useBackgroundMusic();
  const narration = usePageNarration();
  const flipRef = useRef<FlipBookHandle>(null);

  // Reading mode is silent — pause the soundtrack here, resume on exit.
  useEffect(() => {
    music.pause();
    return () => music.ensureStarted();
  }, [music]);

  // Deterministic single/spread from a width breakpoint (not aspect ratio).
  const [mode, setMode] = useState<ReaderMode>(() =>
    typeof window !== 'undefined' && window.innerWidth >= SPREAD_BREAKPOINT ? 'spread' : 'single',
  );
  useEffect(() => {
    const onResize = () => setMode(window.innerWidth >= SPREAD_BREAKPOINT ? 'spread' : 'single');
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);

  const style = useMemo(() => resolveStyle(story.style), [story.style]);

  // Build the leaves: front cover, single faces or text/illustration pairs, then
  // a matching back cover (no title) so the book can be closed at the end.
  const pages = useMemo<FlipPage[]>(() => {
    const leaves: FlipPage[] = [{ content: <CoverFace story={story} />, hard: true }];
    for (const page of story.page) {
      if (mode === 'single') {
        leaves.push({ content: <SingleFace page={page} style={style} /> });
      } else {
        leaves.push({ content: <TextFace page={page} style={style} /> });
        leaves.push({ content: <Illustration url={page.illustration_url} bg={style.backgroundColor} /> });
      }
    }
    leaves.push({ content: <CoverFace story={story} showTitle={false} />, hard: true });
    return leaves;
  }, [story, mode, style]);

  // Size the book from the VIEWPORT (not the area it sits in). Measuring the
  // area would feed back on itself — the fixed-height book grows the column,
  // which grows the area, which would size an even bigger book. We instead
  // reserve fixed space for the chrome (app bar + narration bar + controls) so
  // the book always leaves room for the bottom controls. Page aspect is 480:680.
  const areaRef = useRef<HTMLDivElement>(null);
  const [box, setBox] = useState<{ w: number; h: number } | null>(null);
  useEffect(() => {
    const ratio = 680 / 480;
    const cols = mode === 'spread' ? 2 : 1;
    const CHROME_V = 248; // app bar + narration bar + page controls + padding
    const CHROME_H = 32;
    const measure = () => {
      const availH = Math.max(220, window.innerHeight - CHROME_V);
      const availW = Math.max(200, window.innerWidth - CHROME_H);
      // Cap a single page so the book doesn't sprawl on very large monitors.
      const pageW = Math.min(availW / cols, availH / ratio, 460);
      setBox({ w: Math.floor(pageW * cols), h: Math.floor(pageW * ratio) });
    };
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  }, [mode]);

  const [leaf, setLeaf] = useState(0);
  // The book remounts at the cover whenever the leaf set changes (mode/story);
  // keep the page indicator in sync.
  useEffect(() => setLeaf(0), [pages]);

  // Map a flip-engine leaf index back to its story page and play its narration.
  const onFlip = (current: number) => {
    setLeaf(current);
    if (current <= 0) {
      narration.openPage(null);
      return;
    }
    const pageIndex = mode === 'single' ? current - 1 : Math.floor((current - 1) / 2);
    narration.openPage(story.page[pageIndex]?.audio_url);
  };

  return (
    <MagicScaffold
      showMusicControls={false}
      title={story.title}
      leading={
        <IconButton title="Close" onClick={() => navigate('/stories')}>
          ✕
        </IconButton>
      }
    >
      <div className="flex min-h-0 flex-1 flex-col">
        <div
          ref={areaRef}
          className="flex min-h-0 flex-1 items-center justify-center overflow-hidden px-3 py-2"
        >
          {box && (
            <div style={{ width: box.w, height: box.h }}>
              <FlipBook
                key={`${mode}-${pages.length}`}
                ref={flipRef}
                pages={pages}
                width={480}
                height={680}
                usePortrait={mode === 'single'}
                onFlip={onFlip}
                className="h-full w-full"
              />
            </div>
          )}
        </div>

        <NarrationBar narration={narration} />

        <div className="flex items-center justify-center gap-8 pb-4 pt-1">
          <NavButton title="Previous" onClick={() => flipRef.current?.prev()}>
            ‹
          </NavButton>
          <span className="min-w-16 text-center text-sm text-ink-muted">
            {Math.min(leaf + 1, pages.length)} / {pages.length}
          </span>
          <NavButton title="Next" onClick={() => flipRef.current?.next()}>
            ›
          </NavButton>
        </div>
      </div>
    </MagicScaffold>
  );
}

function NavButton({
  title,
  onClick,
  children,
}: {
  title: string;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      title={title}
      aria-label={title}
      onClick={onClick}
      className="flex h-12 w-12 items-center justify-center rounded-full border text-2xl text-gold transition hover:bg-white/10"
      style={{
        background: 'color-mix(in srgb, var(--color-night-top) 55%, transparent)',
        borderColor: 'color-mix(in srgb, var(--color-lilac) 40%, transparent)',
        boxShadow: '0 0 18px color-mix(in srgb, var(--color-gold) 35%, transparent)',
      }}
    >
      {children}
    </button>
  );
}

function fmt(seconds: number): string {
  if (!Number.isFinite(seconds)) return '0:00';
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60)
    .toString()
    .padStart(2, '0');
  return `${m}:${s}`;
}

/** Per-page narration controls: play/pause, scrubber, restart, auto-narrate. */
function NarrationBar({ narration }: { narration: ReturnType<typeof usePageNarration> }) {
  const { hasAudio, isPlaying, isLoading, autoplay, position, duration } = narration;
  return (
    <div className="flex justify-center px-6 pb-1">
      <div
        className="flex h-[84px] w-full max-w-[520px] items-center gap-2 rounded-[28px] border px-3"
        style={{
          background: 'color-mix(in srgb, var(--color-night-top) 45%, transparent)',
          borderColor: 'color-mix(in srgb, var(--color-lilac) 25%, transparent)',
        }}
      >
        {isLoading ? (
          <span className="flex h-10 w-10 items-center justify-center">
            <Spinner size={22} />
          </span>
        ) : (
          <button
            type="button"
            disabled={!hasAudio}
            onClick={narration.togglePlay}
            title={hasAudio ? (isPlaying ? 'Pause' : 'Play narration') : 'No narration on this page'}
            className="flex h-10 w-10 items-center justify-center text-3xl text-gold disabled:text-ink-muted/40"
          >
            {isPlaying ? '⏸' : '▶'}
          </button>
        )}

        <div className="flex-1">
          {hasAudio ? (
            <div className="flex flex-col">
              <input
                type="range"
                min={0}
                max={duration > 0 ? duration : 1}
                step={0.1}
                value={Math.min(position, duration || 0)}
                onChange={(e) => narration.seek(Number(e.target.value))}
                className="accent-[var(--color-gold)]"
              />
              <div className="flex justify-between px-1 text-[11px] text-ink-muted">
                <span>{fmt(position)}</span>
                <span>{fmt(duration)}</span>
              </div>
            </div>
          ) : (
            <span className="text-[13px] text-ink-muted">No narration on this page</span>
          )}
        </div>

        <button
          type="button"
          disabled={!hasAudio}
          onClick={narration.replay}
          title="Restart narration"
          className="flex h-9 w-9 items-center justify-center text-xl text-ink disabled:text-ink-muted/40"
        >
          ↺
        </button>
        <button
          type="button"
          onClick={() => narration.setAutoplay(!autoplay)}
          title={autoplay ? 'Auto-narrate on' : 'Auto-narrate off'}
          className={
            autoplay
              ? 'flex h-9 w-9 items-center justify-center text-xl text-gold'
              : 'flex h-9 w-9 items-center justify-center text-xl text-ink-muted'
          }
        >
          {autoplay ? '📖' : '📕'}
        </button>
      </div>
    </div>
  );
}
