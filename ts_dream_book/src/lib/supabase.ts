import { createClient } from '@supabase/supabase-js';
import type { Database } from './database.types';

const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  throw new Error(
    'Missing VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY. Copy .env.example to .env.local.',
  );
}

/**
 * Typed Supabase client. Passing the generated `Database` type makes every
 * `.from('story')`, column, filter, and `.select()` shape fully type-checked and
 * auto-completed — there is no hand-written model that can drift from the schema.
 *
 * Regenerate types after any schema change with `npm run gen:types`.
 */
export const supabase = createClient<Database>(url, anonKey);
