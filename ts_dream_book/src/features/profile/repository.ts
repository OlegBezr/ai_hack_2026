import { supabase } from '../../lib/supabase';
import type { Tables, TablesInsert } from '../../lib/database.types';

export type ProfileRow = Tables<'profile'>;

/** Fetch the signed-in user's profile row (null if not provisioned yet). */
export async function fetchMyProfile(userId: string): Promise<ProfileRow | null> {
  const { data, error } = await supabase
    .from('profile')
    .select('*')
    .eq('id', userId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

/**
 * Upsert the display name — resilient if the auto-provision trigger hasn't
 * created the row yet (mirrors the Flutter `ProfileRepository.updateName`).
 */
export async function updateProfileName(userId: string, name: string): Promise<ProfileRow> {
  const row: TablesInsert<'profile'> = { id: userId, name };
  const { data, error } = await supabase
    .from('profile')
    .upsert(row, { onConflict: 'id' })
    .select('*')
    .single();
  if (error) throw error;
  return data;
}
