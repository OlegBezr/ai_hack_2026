import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { MagicScaffold } from '../../components/MagicScaffold';
import { Avatar, Button, GlassCard, SectionLabel, Spinner, TextField } from '../../components/ui';
import { useAuth } from '../auth/AuthProvider';
import { useToast } from '../../lib/toast';
import { fetchMyProfile, updateProfileName, type ProfileRow } from './repository';

/**
 * The traveller's own page in the twilight storybook — a React port of the
 * Flutter `profile_screen.dart`. Shows the read-only email of the gate they
 * passed through and lets them re-engrave the display name carried through
 * the app. Loads the profile on mount and upserts the name on save.
 */

/** Pull a human message out of an unknown thrown value without leaning on `any`. */
function messageOf(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

export function ProfileScreen() {
  const { user } = useAuth();
  const toast = useToast();
  const navigate = useNavigate();

  const [profile, setProfile] = useState<ProfileRow | null>(null);
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);

  const userId = user?.id;

  // Fetch the signed-in traveller's profile row, seeding the name field.
  const load = useCallback(async () => {
    if (!userId) return;
    setLoading(true);
    setLoadError(null);
    try {
      const row = await fetchMyProfile(userId);
      setProfile(row);
      setName(row?.name ?? '');
    } catch (err: unknown) {
      setLoadError(messageOf(err));
    } finally {
      setLoading(false);
    }
  }, [userId]);

  useEffect(() => {
    void load();
  }, [load]);

  // Engrave the new display name (upsert) and whisper a confirmation.
  async function save() {
    if (!userId) return;
    setSaving(true);
    try {
      const row = await updateProfileName(userId, name.trim());
      setProfile(row);
      toast.show('Profile saved');
    } catch (err: unknown) {
      toast.error(messageOf(err));
    } finally {
      setSaving(false);
    }
  }

  // Route guard ensures auth, but never render against a null user.
  if (!user) return null;

  const initial = (profile?.name || user.email || '?').charAt(0);

  const backButton = (
    <Button variant="text" onClick={() => navigate('/stories')}>
      ← Back
    </Button>
  );

  return (
    <MagicScaffold title="Profile" leading={backButton}>
      <div className="mx-auto w-full max-w-[480px] overflow-y-auto p-6">
        {loading ? (
          /* ── Summoning the profile ──────────────────────────────────────── */
          <div className="flex justify-center py-20">
            <Spinner size={32} />
          </div>
        ) : loadError ? (
          /* ── The page would not turn ────────────────────────────────────── */
          <div className="flex flex-col items-center gap-4 py-16 text-center">
            <span className="text-3xl text-danger">⚠</span>
            <p className="text-sm text-ink-muted">{loadError}</p>
            <Button variant="outlined" onClick={() => void load()}>
              Retry
            </Button>
          </div>
        ) : (
          <>
            {/* Gold initial sigil */}
            <div className="flex justify-center">
              <Avatar size={88} initial={initial} />
            </div>

            <div className="h-7" />

            {/* ── Account: the gate they entered through (read-only) ────────── */}
            {user.email && (
              <>
                <SectionLabel>ACCOUNT</SectionLabel>
                <div className="h-2" />
                <GlassCard className="flex items-center gap-3">
                  <span className="text-lg text-lilac" aria-hidden>
                    ✉
                  </span>
                  <div className="flex min-w-0 flex-1 flex-col">
                    <span className="text-[13px] font-medium text-ink">Email</span>
                    <span className="truncate text-[13px] text-ink-muted">{user.email}</span>
                  </div>
                  <span className="text-base text-ink-muted" title="Read-only" aria-label="Read-only">
                    🔒
                  </span>
                </GlassCard>
              </>
            )}

            <div className="h-7" />

            {/* ── Display name: how their name appears in the app ──────────── */}
            <SectionLabel>DISPLAY NAME</SectionLabel>
            <div className="h-2" />
            <TextField
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Your display name"
              helper="How your name appears in the app."
              prefix={<span aria-hidden>🏷</span>}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  void save();
                }
              }}
            />

            <div className="h-6" />

            <Button
              variant="filled"
              loading={saving}
              disabled={saving}
              onClick={() => void save()}
              icon={<span aria-hidden>💾</span>}
              className="w-full"
            >
              {saving ? 'Saving…' : 'Save'}
            </Button>
          </>
        )}
      </div>
    </MagicScaffold>
  );
}
