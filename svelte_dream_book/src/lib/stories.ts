import { supabase } from './supabase';
import type { TablesInsert, TablesUpdate, Json } from './database.types';
import type { StoryRow, StoryWithPages, PageRow, StoryStyle } from './types';

/**
 * Data access for stories + pages — the typed equivalent of the Flutter
 * `stories_repository.dart`. RLS scopes every row to the signed-in author, so
 * these just return whatever the caller is allowed to see.
 */

/** All of the current user's stories with their pages, oldest first. */
export async function listStories(): Promise<StoryWithPages[]> {
  const { data, error } = await supabase
    .from('story')
    .select('*, page(*)')
    .order('created_at', { ascending: true });

  if (error) throw error;
  // Pages come back unordered from the join; sort each story's pages by position.
  for (const s of data) s.page.sort((a, b) => a.position - b.position);
  return data;
}

/** A single story with its pages eagerly loaded and ordered by `position`. */
export async function getStory(id: string): Promise<StoryWithPages | null> {
  const { data, error } = await supabase
    .from('story')
    .select('*, page(*)')
    .eq('id', id)
    .order('position', { foreignTable: 'page', ascending: true })
    .maybeSingle();

  if (error) throw error;
  return data;
}

/** Create a new (empty) story. DB fills id/created_at/author_id. */
export async function createStory(title: string): Promise<StoryWithPages> {
  const { data, error } = await supabase
    .from('story')
    .insert({ title })
    .select('*, page(*)')
    .single();

  if (error) throw error;
  return data;
}

/** Patch a story; only the provided fields are written. */
export async function updateStory(
  id: string,
  patch: { title?: string; cover_texture?: string; style?: StoryStyle }
): Promise<void> {
  const body: TablesUpdate<'story'> = {};
  if (patch.title !== undefined) body.title = patch.title;
  if (patch.cover_texture !== undefined) body.cover_texture = patch.cover_texture;
  if (patch.style !== undefined) body.style = patch.style as Json;
  if (Object.keys(body).length === 0) return;

  const { error } = await supabase.from('story').update(body).eq('id', id);
  if (error) throw error;
}

/** Delete a story (pages cascade in the DB). */
export async function deleteStory(id: string): Promise<void> {
  const { error } = await supabase.from('story').delete().eq('id', id);
  if (error) throw error;
}

/** Append a page at `position` with the given text. */
export async function createPage(
  storyId: string,
  position: number,
  text: string
): Promise<PageRow> {
  const insert: TablesInsert<'page'> = { story_id: storyId, position, text };
  const { data, error } = await supabase.from('page').insert(insert).select().single();

  if (error) throw error;
  return data;
}

/** Patch a page; only the provided fields are written. */
export async function updatePage(
  id: string,
  patch: { text?: string; position?: number }
): Promise<void> {
  const body: TablesUpdate<'page'> = {};
  if (patch.text !== undefined) body.text = patch.text;
  if (patch.position !== undefined) body.position = patch.position;
  if (Object.keys(body).length === 0) return;

  const { error } = await supabase.from('page').update(body).eq('id', id);
  if (error) throw error;
}

export async function deletePage(id: string): Promise<void> {
  const { error } = await supabase.from('page').delete().eq('id', id);
  if (error) throw error;
}

/**
 * Swap two adjacent pages. Uses a temporary `-1` placeholder to dodge the
 * `unique(story_id, position)` constraint, exactly like the Flutter reorder.
 */
export async function swapPagePositions(a: PageRow, b: PageRow): Promise<void> {
  await updatePage(a.id, { position: -1 });
  await updatePage(b.id, { position: a.position });
  await updatePage(a.id, { position: b.position });
}

export type { StoryRow };
