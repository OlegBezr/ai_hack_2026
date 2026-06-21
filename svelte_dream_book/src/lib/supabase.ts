import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_ANON_KEY, PUBLIC_SUPABASE_URL } from '$env/static/public';
import type { Database } from './database.types';

/**
 * The one and only Supabase client, fully typed against the generated
 * `Database` schema. Every query off this client gets column-accurate
 * autocomplete and return types — e.g. `supabase.from('story').select()` knows
 * about `title`, `cover_texture`, `style`, etc.
 *
 * This is a browser/SPA client: it persists the auth session in localStorage
 * and refreshes tokens automatically. (For an SSR deployment you'd swap this for
 * `@supabase/ssr`'s cookie-based clients — see README.)
 */
export const supabase = createClient<Database>(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true
  }
});
