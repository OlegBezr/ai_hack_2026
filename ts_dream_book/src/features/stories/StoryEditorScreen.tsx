import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { MagicScaffold } from '../../components/MagicScaffold';
import { GlassCard, Button, IconButton, TextField, TextArea, Spinner, SectionLabel } from '../../components/ui';
import { useToast } from '../../lib/toast';
import {
  getStoryWithPages,
  updateStory,
  createPage,
  updatePage,
  deletePage,
  swapPages,
  generateIllustration,
  generateAudio,
  generateCoverTexture,
} from './repository';
import { type StoryStyle, type StoryWithPages, type PageRow } from './types';

/* ───────────────────────────────────────────────────────────────────────────
   The author's workbench — React port of `story_editor_screen.dart`. Rename the
   tale, conjure a cover texture, tune the story-wide page styling, and edit each
   page (text, Midjourney illustration, Deepgram narration). Every mutation
   re-reads the story so the screen always mirrors what's stored.
   ─────────────────────────────────────────────────────────────────────────── */

/** Narrow an unknown thrown value to a human-readable message. */
function messageOf(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

/** Curated preset swatches for the text / background pickers (null = default). */
const COLOR_SWATCHES: Array<string | null> = [
  null,
  '#000000',
  '#FFFFFF',
  '#5D4037', // brown
  '#B71C1C', // red
  '#1A237E', // indigo
  '#F5EFE0', // cream
];

const FONT_OPTIONS: Array<{ value: StoryStyle['fontFamily']; label: string }> = [
  { value: undefined, label: 'Default' },
  { value: 'Serif', label: 'Serif' },
  { value: 'Sans', label: 'Sans' },
  { value: 'Mono', label: 'Mono' },
];

const ALIGN_OPTIONS: Array<{ value: NonNullable<StoryStyle['textAlign']>; glyph: string }> = [
  { value: 'left', glyph: '≡' },
  { value: 'center', glyph: '≣' },
  { value: 'right', glyph: '≡' },
  { value: 'justify', glyph: '☰' },
];

export function StoryEditorScreen() {
  const navigate = useNavigate();
  const toast = useToast();
  const { id } = useParams();

  const [story, setStory] = useState<StoryWithPages | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Title + cover + style action state.
  const [title, setTitle] = useState('');
  const [savingTitle, setSavingTitle] = useState(false);
  const [generatingCover, setGeneratingCover] = useState(false);
  const [savingStyle, setSavingStyle] = useState(false);
  const [styleOpen, setStyleOpen] = useState(false);

  // A single in-flight prompt request, resolved by the modal (no window.prompt).
  const [prompt, setPrompt] = useState<PromptRequest | null>(null);

  /** Fetch (or re-fetch) the story and its ordered pages. */
  const load = useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError(null);
    try {
      const next = await getStoryWithPages(id);
      if (!next) throw new Error('Story not found');
      setStory(next);
      setTitle(next.title);
    } catch (err: unknown) {
      setError(messageOf(err));
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  /** Save the title (skips no-op / empty); the button + Enter both call this. */
  const handleSaveTitle = useCallback(async () => {
    if (!id || !story) return;
    const trimmed = title.trim();
    if (!trimmed || trimmed === story.title) return;
    setSavingTitle(true);
    try {
      await updateStory(id, { title: trimmed });
      await load();
      toast.show('Title saved');
    } catch (err: unknown) {
      toast.error(messageOf(err));
    } finally {
      setSavingTitle(false);
    }
  }, [id, story, title, load, toast]);

  /** Ask for a description, then conjure the Midjourney cover art. */
  const handleGenerateCover = useCallback(async () => {
    if (!id || !story) return;
    const description = await openPrompt(setPrompt, {
      title: 'Cover texture prompt',
      placeholder: 'Describe the cover texture…',
      initial: story.title,
    });
    if (!description) return;
    setGeneratingCover(true);
    try {
      await generateCoverTexture(id, description);
      await load();
      toast.show('Cover texture generated');
    } catch (err: unknown) {
      toast.error(messageOf(err));
    } finally {
      setGeneratingCover(false);
    }
  }, [id, story, load, toast]);

  /** Persist the story-wide style (built whole so any field can clear to undefined). */
  const applyStyle = useCallback(
    async (next: StoryStyle) => {
      if (!id) return;
      setSavingStyle(true);
      try {
        await updateStory(id, { style: next });
        await load();
        toast.show('Style saved');
      } catch (err: unknown) {
        toast.error(messageOf(err));
      } finally {
        setSavingStyle(false);
      }
    },
    [id, load, toast],
  );

  /** Append a fresh page after the last position. */
  const handleAddPage = useCallback(async () => {
    if (!id || !story) return;
    const nextPos = story.page.length
      ? Math.max(...story.page.map((p) => p.position)) + 1
      : 0;
    try {
      await createPage(id, nextPos, '');
      await load();
    } catch (err: unknown) {
      toast.error(messageOf(err));
    }
  }, [id, story, load, toast]);

  /** Banish a page after a confirm. */
  const handleDeletePage = useCallback(
    async (page: PageRow) => {
      if (!window.confirm('Delete this page? This cannot be undone.')) return;
      try {
        await deletePage(page.id);
        await load();
      } catch (err: unknown) {
        toast.error(messageOf(err));
      }
    },
    [load, toast],
  );

  /** Swap a page with its neighbour (delta -1 = up, +1 = down). */
  const handleMovePage = useCallback(
    async (index: number, delta: number) => {
      if (!story) return;
      const target = index + delta;
      if (target < 0 || target >= story.page.length) return;
      try {
        await swapPages(story.page[index], story.page[target]);
        await load();
      } catch (err: unknown) {
        toast.error(messageOf(err));
      }
    },
    [story, load, toast],
  );

  return (
    <MagicScaffold
      title="Edit story"
      leading={
        <IconButton title="Back" onClick={() => navigate('/stories')}>
          ←
        </IconButton>
      }
      fab={
        story && (
          <Button variant="filled" icon="＋" onClick={() => void handleAddPage()}>
            Add page
          </Button>
        )
      }
    >
      <div className="mx-auto w-full max-w-[640px] px-4 pb-[100px] pt-6">
        {loading ? (
          <div className="flex justify-center py-20">
            <Spinner size={32} />
          </div>
        ) : error || !story ? (
          <div className="flex flex-col items-center gap-3 py-20 text-center">
            <span className="text-3xl text-danger">⚠</span>
            <p className="text-ink-muted">{error ?? 'Story not found'}</p>
            <Button variant="outlined" onClick={() => void load()}>
              Retry
            </Button>
          </div>
        ) : (
          <div className="flex flex-col gap-4">
            {/* Title row. */}
            <div className="flex items-end gap-2">
              <div className="flex-1">
                <TextField
                  label="Story title"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') void handleSaveTitle();
                  }}
                />
              </div>
              <IconButton
                title="Save title"
                disabled={savingTitle}
                onClick={() => void handleSaveTitle()}
              >
                {savingTitle ? <Spinner size={18} /> : '💾'}
              </IconButton>
            </div>

            {/* Cover texture (Midjourney). */}
            <section className="flex flex-col gap-2">
              <SectionLabel>Cover</SectionLabel>
              {story.cover_texture && (
                <img
                  src={story.cover_texture}
                  alt="Cover texture"
                  className="h-40 w-full rounded-2xl object-cover"
                />
              )}
              <div>
                <Button
                  variant="outlined"
                  loading={generatingCover}
                  icon="🖼"
                  onClick={() => void handleGenerateCover()}
                >
                  Generate cover texture
                </Button>
              </div>
            </section>

            {/* Story-wide page styling. */}
            <StyleSection
              open={styleOpen}
              onToggle={() => setStyleOpen((v) => !v)}
              saving={savingStyle}
              style={(story.style ?? {}) as StoryStyle}
              onApply={(next) => void applyStyle(next)}
            />

            {/* Pages. */}
            <section className="flex flex-col gap-3">
              <SectionLabel>Pages</SectionLabel>
              {story.page.length === 0 ? (
                <p className="py-6 text-center text-ink-muted">No pages yet. Add one below.</p>
              ) : (
                story.page.map((page, index) => (
                  <PageEditor
                    key={page.id}
                    page={page}
                    index={index}
                    total={story.page.length}
                    requestPrompt={(opts) => openPrompt(setPrompt, opts)}
                    onMoveUp={() => void handleMovePage(index, -1)}
                    onMoveDown={() => void handleMovePage(index, 1)}
                    onDelete={() => void handleDeletePage(page)}
                  />
                ))
              )}
            </section>
          </div>
        )}
      </div>

      {prompt && <PromptModal request={prompt} onClose={() => setPrompt(null)} />}
    </MagicScaffold>
  );
}

/* ── Prompt modal ─────────────────────────────────────────────────────────────
   A reusable in-file modal that resolves a Promise<string | null> — the React
   stand-in for Flutter's `showDialog<String>`. `openPrompt` stashes the request
   (with its resolver) in screen state; the modal renders it and resolves on
   Cancel / Generate. ──────────────────────────────────────────────────────── */

interface PromptOptions {
  title: string;
  placeholder: string;
  initial?: string;
}

interface PromptRequest extends PromptOptions {
  resolve: (value: string | null) => void;
}

/** Open the shared prompt modal and await the entered (trimmed) string, or null. */
function openPrompt(
  setPrompt: (req: PromptRequest | null) => void,
  options: PromptOptions,
): Promise<string | null> {
  return new Promise((resolve) => {
    setPrompt({ ...options, resolve });
  });
}

function PromptModal({ request, onClose }: { request: PromptRequest; onClose: () => void }) {
  const [value, setValue] = useState(request.initial ?? '');

  const finish = (result: string | null) => {
    request.resolve(result);
    onClose();
  };

  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center px-4"
      style={{ background: 'rgba(0,0,0,0.55)' }}
      onClick={() => finish(null)}
    >
      <div className="w-full max-w-md" onClick={(e) => e.stopPropagation()}>
        <GlassCard padding="p-5">
          <h2 className="mb-4 font-display text-xl text-gold">{request.title}</h2>
          <TextArea
            rows={4}
            autoFocus
            value={value}
            placeholder={request.placeholder}
            onChange={(e) => setValue(e.target.value)}
          />
          <div className="mt-5 flex justify-end gap-2">
            <Button variant="text" onClick={() => finish(null)}>
              Cancel
            </Button>
            <Button variant="filled" onClick={() => finish(value.trim())}>
              Generate
            </Button>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}

/* ── Style section ────────────────────────────────────────────────────────────
   Collapsible card of story-wide controls — font family, size scale, alignment,
   text + background swatches, and a live preview. Each control hands a fully
   rebuilt `StoryStyle` to `onApply` so any field can be cleared to undefined. ── */

function StyleSection({
  open,
  onToggle,
  saving,
  style,
  onApply,
}: {
  open: boolean;
  onToggle: () => void;
  saving: boolean;
  style: StoryStyle;
  onApply: (next: StoryStyle) => void;
}) {
  // Local size for smooth dragging; committed to the server on pointer up.
  const [localScale, setLocalScale] = useState<number | null>(null);
  const scale = localScale ?? style.fontSizeScale ?? 1;

  /** Rebuild the style with a single field overridden (others preserved). */
  const withField = (patch: Partial<StoryStyle>): StoryStyle => ({ ...style, ...patch });

  return (
    <GlassCard padding="p-0">
      <button
        type="button"
        onClick={onToggle}
        className="flex w-full items-center gap-3 px-4 py-3 text-left"
      >
        <div className="flex-1">
          <p className="font-serif text-[17px] text-ink">Page text style</p>
          <p className="text-xs text-ink-muted">Applies to all pages</p>
        </div>
        {saving && <Spinner size={16} />}
        <span className="text-lilac">{open ? '▾' : '▸'}</span>
      </button>

      {open && (
        <div className="flex flex-col gap-4 px-4 pb-4">
          {/* Font family. */}
          <ControlRow label="Font">
            <div className="flex flex-wrap gap-2">
              {FONT_OPTIONS.map((opt) => {
                const selected = (style.fontFamily ?? undefined) === opt.value;
                return (
                  <button
                    key={opt.label}
                    type="button"
                    onClick={() => onApply(withField({ fontFamily: opt.value }))}
                    className={
                      'rounded-xl border px-3 py-1.5 text-sm transition ' +
                      (selected ? 'bg-gold text-[#2a1b05]' : 'text-ink hover:bg-white/5')
                    }
                    style={{ borderColor: 'color-mix(in srgb, var(--color-lilac) 35%, transparent)' }}
                  >
                    {opt.label}
                  </button>
                );
              })}
            </div>
          </ControlRow>

          {/* Font size scale. */}
          <ControlRow label="Size">
            <div className="flex items-center gap-3">
              <input
                type="range"
                min={0.8}
                max={2.0}
                step={0.1}
                value={scale}
                onChange={(e) => setLocalScale(Number(e.target.value))}
                onPointerUp={() => {
                  onApply(withField({ fontSizeScale: scale }));
                  setLocalScale(null);
                }}
                className="flex-1 accent-[var(--color-gold)]"
              />
              <span className="w-12 text-right text-sm text-ink-muted">{scale.toFixed(1)}×</span>
            </div>
          </ControlRow>

          {/* Text alignment. */}
          <ControlRow label="Align">
            <div className="flex gap-2">
              {ALIGN_OPTIONS.map((opt) => {
                const selected = (style.textAlign ?? 'left') === opt.value;
                return (
                  <button
                    key={opt.value}
                    type="button"
                    title={opt.value}
                    onClick={() => onApply(withField({ textAlign: opt.value }))}
                    className={
                      'inline-flex h-9 w-9 items-center justify-center rounded-xl border text-base transition ' +
                      (selected ? 'bg-gold text-[#2a1b05]' : 'text-ink hover:bg-white/5')
                    }
                    style={{ borderColor: 'color-mix(in srgb, var(--color-lilac) 35%, transparent)' }}
                  >
                    {opt.glyph}
                  </button>
                );
              })}
            </div>
          </ControlRow>

          {/* Text color. */}
          <ControlRow label="Text">
            <SwatchRow
              selected={style.textColor ?? null}
              onPick={(hex) => onApply(withField({ textColor: hex ?? undefined }))}
            />
          </ControlRow>

          {/* Page background color. */}
          <ControlRow label="Background">
            <SwatchRow
              selected={style.backgroundColor ?? null}
              onPick={(hex) => onApply(withField({ backgroundColor: hex ?? undefined }))}
            />
          </ControlRow>

          {/* Live preview. */}
          <div
            className="rounded-2xl border p-3"
            style={{
              background: style.backgroundColor ?? 'var(--color-night-top)',
              color: style.textColor ?? 'var(--color-ink)',
              textAlign: style.textAlign ?? 'left',
              fontSize: 14 * scale,
              borderColor: 'color-mix(in srgb, var(--color-lilac) 25%, transparent)',
            }}
          >
            Once upon a time, in a land far away...
          </div>
        </div>
      )}
    </GlassCard>
  );
}

/** A labelled control row — a fixed-width caption beside its control. */
function ControlRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center gap-3">
      <span className="w-24 shrink-0 text-sm text-ink-muted">{label}</span>
      <div className="flex-1">{children}</div>
    </div>
  );
}

/** A row of preset color circles + a native custom picker; null = "Default". */
function SwatchRow({
  selected,
  onPick,
}: {
  selected: string | null;
  onPick: (hex: string | null) => void;
}) {
  const norm = (hex: string | null) => hex?.toUpperCase() ?? null;
  // True when the saved value isn't one of the presets (a custom color).
  const isCustom =
    selected != null && !COLOR_SWATCHES.some((c) => c != null && norm(c) === norm(selected));

  return (
    <div className="flex flex-wrap items-center gap-2">
      {COLOR_SWATCHES.map((hex, i) => {
        const isSelected = norm(hex) === norm(selected);
        return (
          <button
            key={i}
            type="button"
            title={hex ?? 'Default'}
            onClick={() => onPick(hex)}
            className={
              'inline-flex h-7 w-7 items-center justify-center rounded-full border transition ' +
              (isSelected ? 'ring-2 ring-gold' : '')
            }
            style={{
              background: hex ?? 'transparent',
              borderColor: 'color-mix(in srgb, var(--color-lilac) 40%, transparent)',
            }}
          >
            {hex == null && <span className="text-xs text-ink-muted">⦸</span>}
          </button>
        );
      })}
      {/* Custom color — a native picker that doubles as the "is custom" indicator. */}
      <label
        className={
          'inline-flex h-7 w-7 cursor-pointer items-center justify-center overflow-hidden rounded-full border ' +
          (isCustom ? 'ring-2 ring-gold' : '')
        }
        style={{
          background: isCustom ? (selected as string) : undefined,
          borderColor: 'color-mix(in srgb, var(--color-lilac) 40%, transparent)',
        }}
        title="Custom color"
      >
        {!isCustom && <span className="text-xs text-lilac">＋</span>}
        <input
          type="color"
          value={isCustom ? (selected as string) : '#3F51B5'}
          onChange={(e) => onPick(e.target.value.toUpperCase())}
          className="h-0 w-0 opacity-0"
        />
      </label>
    </div>
  );
}

/* ── Page editor card ─────────────────────────────────────────────────────────
   One GlassCard per page: reorder / delete controls, an editable text body, and
   the three AI actions (save text, illustration, narration). Generated assets
   live in local state so they appear without a full reload. ──────────────────── */

function PageEditor({
  page,
  index,
  total,
  requestPrompt,
  onMoveUp,
  onMoveDown,
  onDelete,
}: {
  page: PageRow;
  index: number;
  total: number;
  requestPrompt: (opts: PromptOptions) => Promise<string | null>;
  onMoveUp: () => void;
  onMoveDown: () => void;
  onDelete: () => void;
}) {
  const toast = useToast();

  const [text, setText] = useState(page.text ?? '');
  const [illustrationUrl, setIllustrationUrl] = useState<string | null>(page.illustration_url);
  const [audioUrl, setAudioUrl] = useState<string | null>(page.audio_url);

  const [savingText, setSavingText] = useState(false);
  const [generatingImage, setGeneratingImage] = useState(false);
  const [generatingAudio, setGeneratingAudio] = useState(false);

  // Keep the latest text reachable inside async closures without re-binding them.
  const textRef = useRef(text);
  textRef.current = text;

  const handleSaveText = useCallback(async () => {
    setSavingText(true);
    try {
      await updatePage(page.id, { text: textRef.current });
      toast.show('Page saved');
    } catch (err: unknown) {
      toast.error(messageOf(err));
    } finally {
      setSavingText(false);
    }
  }, [page.id, toast]);

  const handleGenerateImage = useCallback(async () => {
    const description = await requestPrompt({
      title: 'Illustration prompt',
      placeholder: 'Describe the illustration…',
      initial: textRef.current.trim(),
    });
    if (!description) return;
    setGeneratingImage(true);
    try {
      const url = await generateIllustration(page.id, description);
      setIllustrationUrl(url);
      toast.show('Illustration generated');
    } catch (err: unknown) {
      toast.error(messageOf(err));
    } finally {
      setGeneratingImage(false);
    }
  }, [page.id, requestPrompt, toast]);

  const handleGenerateAudio = useCallback(async () => {
    setGeneratingAudio(true);
    try {
      const trimmed = textRef.current.trim();
      const url = await generateAudio(page.id, trimmed || undefined);
      setAudioUrl(url);
      toast.show('Audio generated');
    } catch (err: unknown) {
      toast.error(messageOf(err));
    } finally {
      setGeneratingAudio(false);
    }
  }, [page.id, toast]);

  return (
    <GlassCard>
      <div className="flex flex-col gap-3">
        {/* Header: page number + reorder / delete controls. */}
        <div className="flex items-center gap-1">
          <span className="flex-1 font-serif text-[17px] text-ink">Page {index + 1}</span>
          <IconButton title="Move up" disabled={index === 0} onClick={onMoveUp}>
            ↑
          </IconButton>
          <IconButton title="Move down" disabled={index === total - 1} onClick={onMoveDown}>
            ↓
          </IconButton>
          <IconButton title="Delete page" className="hover:!text-danger" onClick={onDelete}>
            🗑
          </IconButton>
        </div>

        <TextArea
          rows={4}
          value={text}
          placeholder="Page text…"
          onChange={(e) => setText(e.target.value)}
        />

        {/* AI actions. */}
        <div className="flex flex-wrap gap-2">
          <Button
            variant="outlined"
            loading={savingText}
            icon="💾"
            onClick={() => void handleSaveText()}
          >
            Save text
          </Button>
          <Button
            variant="outlined"
            loading={generatingImage}
            icon="🖼"
            onClick={() => void handleGenerateImage()}
          >
            Generate illustration
          </Button>
          <Button
            variant="outlined"
            loading={generatingAudio}
            icon="🔊"
            onClick={() => void handleGenerateAudio()}
          >
            Generate audio
          </Button>
        </div>

        {illustrationUrl && (
          <img
            src={illustrationUrl}
            alt={`Illustration for page ${index + 1}`}
            className="w-full rounded-2xl object-cover"
          />
        )}

        {audioUrl && (
          <audio controls src={audioUrl} className="w-full">
            Your browser does not support the audio element.
          </audio>
        )}
      </div>
    </GlassCard>
  );
}
