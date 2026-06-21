import type { Session, User } from '@supabase/supabase-js';
import { supabase } from './supabase';

/**
 * App-wide auth state, mirroring the Flutter `authStateProvider` / `sessionProvider`.
 * A single runes-based store that tracks the Supabase session and exposes the
 * OTP (one-time email code) flow used by the Flutter `AuthService`.
 */
class AuthStore {
  session = $state<Session | null>(null);
  /** True until the initial getSession() resolves — used to gate route guards. */
  ready = $state(false);

  private initialized = false;

  get user(): User | null {
    return this.session?.user ?? null;
  }

  get signedIn(): boolean {
    return this.session !== null;
  }

  /** Wire up the session listener once (called from the root layout). */
  init() {
    if (this.initialized) return;
    this.initialized = true;

    supabase.auth.getSession().then(({ data }) => {
      this.session = data.session;
      this.ready = true;
    });

    supabase.auth.onAuthStateChange((_event, session) => {
      this.session = session;
    });
  }

  /** Send a one-time login code to the email (creates the user if new). */
  async signInWithOtp(email: string): Promise<void> {
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: true }
    });
    if (error) throw error;
  }

  /** Verify the 6-digit code; on success the session listener fires. */
  async verifyOtp(email: string, token: string): Promise<void> {
    const { error } = await supabase.auth.verifyOtp({ email, token, type: 'email' });
    if (error) throw error;
  }

  async signOut(): Promise<void> {
    await supabase.auth.signOut();
    this.session = null;
  }
}

export const auth = new AuthStore();
