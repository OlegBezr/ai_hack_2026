import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { MagicScaffold } from '../../components/MagicScaffold';
import { GlassCard, Button, IconButton, Spinner, Avatar, TextField } from '../../components/ui';
import { useAuth } from '../auth/AuthProvider';
import { useToast } from '../../lib/toast';
import { listStories, createStory, deleteStory } from './repository';
import type { StoryRow } from './types';

/* ───────────────────────────────────────────────────────────────────────────
   The reader's library — React port of `stories_list_screen.dart`. Lists the
   signed-in author's tales as glassy cards; opens the reader on tap, the editor
   on edit, and conjures fresh stories from a small twilight modal.
   ─────────────────────────────────────────────────────────────────────────── */

/** First letter of an email for the profile avatar, with a gentle fallback. */
function firstChar(email: string | null | undefined): string {
  return email?.trim()?.[0] ?? '✦';
}

/** Narrow an unknown thrown value to a human-readable message. */
function messageOf(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

export function StoriesListScreen() {
  const navigate = useNavigate();
  const { user, signOut } = useAuth();
  const toast = useToast();

  const [stories, setStories] = useState<StoryRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Create-dialog state.
  const [creating, setCreating] = useState(false);
  const [draftTitle, setDraftTitle] = useState('New story');
  const [saving, setSaving] = useState(false);

  /** Fetch (or re-fetch) the library. */
  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setStories(await listStories());
    } catch (err: unknown) {
      setError(messageOf(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  /** Conjure a new story, then slip straight into the editor. */
  const handleCreate = useCallback(async () => {
    setSaving(true);
    try {
      const s = await createStory(draftTitle.trim() || 'New story');
      setCreating(false);
      navigate('/stories/' + s.id);
    } catch (err: unknown) {
      toast.error(messageOf(err));
    } finally {
      setSaving(false);
    }
  }, [draftTitle, navigate, toast]);

  /** Banish a story after a confirm, then drop it from the shelf. */
  const handleDelete = useCallback(
    async (story: StoryRow) => {
      if (!window.confirm(`Delete "${story.title}"? This cannot be undone.`)) return;
      try {
        await deleteStory(story.id);
        setStories((list) => list.filter((x) => x.id !== story.id));
        toast.show('Story deleted');
      } catch (err: unknown) {
        toast.error(messageOf(err));
      }
    },
    [toast],
  );

  /** Sign out and return to the cover (login) screen. */
  const handleSignOut = useCallback(async () => {
    await signOut();
    navigate('/');
  }, [signOut, navigate]);

  return (
    <MagicScaffold
      title="My Stories"
      actions={
        <>
          <button
            type="button"
            title="Profile"
            aria-label="Profile"
            onClick={() => navigate('/profile')}
            className="rounded-full transition hover:brightness-110 active:scale-95"
          >
            <Avatar size={32} initial={firstChar(user?.email)} />
          </button>
          <IconButton title="Refresh" onClick={() => void load()}>
            ⟳
          </IconButton>
          <IconButton title="Sign out" onClick={() => void handleSignOut()}>
            ⎋
          </IconButton>
        </>
      }
      fab={
        <Button variant="filled" icon="＋" onClick={() => setCreating(true)}>
          New story
        </Button>
      }
    >
      <div className="mx-auto w-full max-w-[560px] px-4 pb-[100px] pt-6">
        <StoriesBody
          loading={loading}
          error={error}
          stories={stories}
          onRetry={() => void load()}
          onOpen={(id) => navigate('/read/' + id)}
          onEdit={(id) => navigate('/stories/' + id)}
          onDelete={(s) => void handleDelete(s)}
        />
      </div>

      {creating && (
        <CreateDialog
          title={draftTitle}
          onChange={setDraftTitle}
          saving={saving}
          onCancel={() => setCreating(false)}
          onCreate={() => void handleCreate()}
        />
      )}
    </MagicScaffold>
  );
}

/* ── Body states ──────────────────────────────────────────────────────────── */

function StoriesBody({
  loading,
  error,
  stories,
  onRetry,
  onOpen,
  onEdit,
  onDelete,
}: {
  loading: boolean;
  error: string | null;
  stories: StoryRow[];
  onRetry: () => void;
  onOpen: (id: string) => void;
  onEdit: (id: string) => void;
  onDelete: (story: StoryRow) => void;
}) {
  if (loading) {
    return (
      <div className="flex justify-center py-20">
        <Spinner size={32} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center gap-3 py-20 text-center">
        <span className="text-3xl text-danger">⚠</span>
        <p className="text-ink-muted">{error}</p>
        <Button variant="outlined" onClick={onRetry}>
          Retry
        </Button>
      </div>
    );
  }

  if (stories.length === 0) {
    return (
      <div className="flex flex-col items-center gap-2 py-24 text-center">
        <span className="text-6xl text-gold" aria-hidden>
          📖
        </span>
        <h2 className="font-display text-[22px] text-gold">Your library awaits</h2>
        <p className="text-ink-muted">Tap &ldquo;New story&rdquo; to begin your first tale.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {stories.map((story) => (
        <StoryCard
          key={story.id}
          story={story}
          onOpen={() => onOpen(story.id)}
          onEdit={() => onEdit(story.id)}
          onDelete={() => onDelete(story)}
        />
      ))}
    </div>
  );
}

/* ── Story card ───────────────────────────────────────────────────────────── */

/** Short, friendly date for a card subtitle (e.g. "Jun 21, 2026"). */
function shortDate(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? ''
    : d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

function StoryCard({
  story,
  onOpen,
  onEdit,
  onDelete,
}: {
  story: StoryRow;
  onOpen: () => void;
  onEdit: () => void;
  onDelete: () => void;
}) {
  // Buttons inside the card must not also fire the card's open-on-tap.
  const guard = (fn: () => void) => (e: React.MouseEvent) => {
    e.stopPropagation();
    fn();
  };

  const subtitle = shortDate(story.created_at);

  return (
    <GlassCard onClick={onOpen}>
      <div className="flex items-center gap-3">
        {/* Gold→amber book badge (a tiny cover-in-the-palm). */}
        <span
          className="inline-flex h-[46px] w-[46px] shrink-0 items-center justify-center rounded-full text-xl text-[#2a1b05]"
          style={{
            background: 'radial-gradient(circle at 35% 30%, var(--color-gold), var(--color-amber))',
            boxShadow: '0 0 16px color-mix(in srgb, var(--color-gold) 40%, transparent)',
          }}
          aria-hidden
        >
          📖
        </span>

        <div className="min-w-0 flex-1">
          <p className="truncate font-serif text-[20px] text-ink">{story.title}</p>
          {subtitle && <p className="text-xs text-ink-muted">{subtitle}</p>}
        </div>

        <div className="flex shrink-0 items-center gap-0.5">
          <IconButton title="Read" onClick={guard(onOpen)}>
            📖
          </IconButton>
          <IconButton title="Edit" onClick={guard(onEdit)}>
            ✎
          </IconButton>
          <IconButton title="Delete" className="!text-ink-muted hover:!text-danger" onClick={guard(onDelete)}>
            🗑
          </IconButton>
        </div>
      </div>
    </GlassCard>
  );
}

/* ── Create-story dialog ──────────────────────────────────────────────────── */

function CreateDialog({
  title,
  onChange,
  saving,
  onCancel,
  onCreate,
}: {
  title: string;
  onChange: (v: string) => void;
  saving: boolean;
  onCancel: () => void;
  onCreate: () => void;
}) {
  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center px-4"
      style={{ background: 'rgba(0,0,0,0.55)' }}
      onClick={onCancel}
    >
      <div className="w-full max-w-sm" onClick={(e) => e.stopPropagation()}>
        <GlassCard padding="p-5">
          <h2 className="mb-4 font-display text-xl text-gold">New story</h2>
          <TextField
            label="Title"
            value={title}
            autoFocus
            disabled={saving}
            onChange={(e) => onChange(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !saving) onCreate();
            }}
          />
          <div className="mt-5 flex justify-end gap-2">
            <Button variant="text" disabled={saving} onClick={onCancel}>
              Cancel
            </Button>
            <Button variant="filled" loading={saving} onClick={onCreate}>
              Create
            </Button>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
