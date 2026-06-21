import { supabase } from './supabase';

/**
 * Profile data access, mirroring the Flutter `ProfileRepository`. The profile
 * row is 1:1 with the auth user (id == auth.users.id) and holds a display name.
 */

export interface UserProfile {
  id: string;
  name: string | null;
}

/** The signed-in user's profile, or null if no row exists yet. */
export async function fetchMyProfile(): Promise<UserProfile | null> {
  const userId = (await supabase.auth.getUser()).data.user?.id;
  if (!userId) throw new Error('Not signed in');

  const { data, error } = await supabase
    .from('profile')
    .select('id, name')
    .eq('id', userId)
    .maybeSingle();

  if (error) throw error;
  return data;
}

/** Upsert the display name (resilient if the auto-provision row is missing). */
export async function updateName(name: string): Promise<UserProfile> {
  const userId = (await supabase.auth.getUser()).data.user?.id;
  if (!userId) throw new Error('Not signed in');

  const { data, error } = await supabase
    .from('profile')
    .upsert({ id: userId, name })
    .select('id, name')
    .single();

  if (error) throw error;
  return data;
}
