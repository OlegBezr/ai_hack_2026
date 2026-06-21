import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { MagicScaffold } from '../../components/MagicScaffold';
import { GlassCard, MagicWordmark, Button, TextField } from '../../components/ui';
import { useAuth } from './AuthProvider';
import { useToast } from '../../lib/toast';

/* ───────────────────────────────────────────────────────────────────────────
   Email-OTP sign in — the React port of the Flutter `login_screen.dart`. Two
   phases share one card: first we collect the email and mail a one-time code,
   then we collect the 6-digit code and verify it. A successful verify flips the
   auth state, which the router guard reacts to; we also push `/stories` as a
   belt-and-suspenders fallback.
   ─────────────────────────────────────────────────────────────────────────── */

/** Pull a human-readable message out of an unknown thrown value. */
function errMessage(e: unknown): string {
  if (e instanceof Error) return e.message;
  return String(e);
}

export function LoginScreen() {
  const auth = useAuth();
  const toast = useToast();
  const navigate = useNavigate();

  // Local form state — the whole flow is driven by `codeSent`.
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [codeSent, setCodeSent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  /** Phase 1 → mail the one-time code (also used by "Resend code"). */
  async function sendCode() {
    const trimmed = email.trim();
    if (trimmed.length === 0 || !trimmed.includes('@')) {
      setError('Enter a valid email address.');
      return;
    }
    setLoading(true);
    try {
      await auth.signInWithOtp(trimmed);
      setCodeSent(true);
      setError(null);
      toast.show('Code sent — check your inbox.');
    } catch (e: unknown) {
      setError(`Could not send code: ${errMessage(e)}`);
    } finally {
      setLoading(false);
    }
  }

  /** Phase 2 → verify the typed code; auth state change handles the redirect. */
  async function verify() {
    if (code.length < 6) {
      setError('Enter the 6-digit code.');
      return;
    }
    setLoading(true);
    try {
      await auth.verifyOtp(email.trim(), code);
      // Guard will redirect on the auth state change; nudge it along anyway.
      navigate('/stories');
    } catch (e: unknown) {
      setError(`Invalid or expired code: ${errMessage(e)}`);
    } finally {
      setLoading(false);
    }
  }

  /** "Change email" → back to phase 1, dropping the half-typed code. */
  function changeEmail() {
    setCodeSent(false);
    setCode('');
    setError(null);
  }

  return (
    <MagicScaffold
      title="Sign in"
      leading={
        <Button variant="text" onClick={() => navigate('/')}>
          ← Back
        </Button>
      }
    >
      <div className="mx-auto flex w-full max-w-[420px] flex-col items-stretch overflow-y-auto py-6">
        <MagicWordmark text="Dream Book" fontSize={34} />
        <div className="h-7" />

        <GlassCard padding="p-6">
          {!codeSent ? (
            /* ── Phase 1: collect email ───────────────────────────────────── */
            <div className="flex flex-col gap-4">
              <div>
                <h2 className="font-display text-[20px] font-bold text-ink">Enter the gate</h2>
                <p className="mt-1 text-[13px] text-ink-muted">
                  Sign in with a one-time email code.
                </p>
              </div>

              <TextField
                label="Email"
                type="email"
                inputMode="email"
                autoComplete="email"
                placeholder="you@example.com"
                prefix={<span aria-hidden>✉</span>}
                value={email}
                disabled={loading}
                onChange={(e) => setEmail(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    void sendCode();
                  }
                }}
              />

              {error && <p className="text-[13px] text-danger">{error}</p>}

              <Button
                variant="filled"
                className="w-full"
                loading={loading}
                onClick={() => void sendCode()}
              >
                Send code
              </Button>
            </div>
          ) : (
            /* ── Phase 2: collect + verify code ───────────────────────────── */
            <div className="flex flex-col gap-4">
              <div>
                <h2 className="font-display text-[20px] font-bold text-ink">Check your owl post</h2>
                <p className="mt-1 text-[13px] text-ink-muted">
                  Enter the 6-digit code we emailed you.
                </p>
              </div>

              <TextField
                label="Email"
                type="email"
                prefix={<span aria-hidden>✉</span>}
                value={email}
                disabled
                onChange={(e) => setEmail(e.target.value)}
              />

              <TextField
                label="6-digit code"
                inputMode="numeric"
                autoComplete="one-time-code"
                maxLength={6}
                placeholder="123456"
                prefix={<span aria-hidden>⚿</span>}
                value={code}
                disabled={loading}
                onChange={(e) => setCode(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    void verify();
                  }
                }}
              />

              {error && <p className="text-[13px] text-danger">{error}</p>}

              <Button
                variant="filled"
                className="w-full"
                loading={loading}
                onClick={() => void verify()}
              >
                Verify
              </Button>

              <div className="flex items-center justify-between">
                <Button variant="text" disabled={loading} onClick={changeEmail}>
                  Change email
                </Button>
                <Button variant="text" disabled={loading} onClick={() => void sendCode()}>
                  Resend code
                </Button>
              </div>
            </div>
          )}
        </GlassCard>
      </div>
    </MagicScaffold>
  );
}
