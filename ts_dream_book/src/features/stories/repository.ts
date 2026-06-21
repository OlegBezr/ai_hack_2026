import { supabase } from '../../lib/supabase';
import type { TablesInsert, TablesUpdate, Json } from '../../lib/database.types';
import type { StoryRow, StoryStyle, StoryWithPages, PageRow } from './types';

/**
 * Stories data access — the React port of the Flutter `StoriesRepository`. All
 * table operations run through the typed Supabase client (RLS scopes every row
 * to the signed-in author); the AI features call the same Supabase edge
 * functions the Flutter app uses (`generate-illustration`, `generate-audio`,
 * `generate-texture`), which authenticate via the session JWT automatically.
 */

/** List the signed-in author's stories, newest first (RLS-scoped). */
export async function listStories(): Promise<StoryRow[]> {
  const { data, error } = await supabase
    .from('story')
    .select('*')
    .order('updated_at', { ascending: false });
  if (error) throw error;
  return data;
}

/** Load a story with its ordered pages — the reader/editor payload. */
export async function getStoryWithPages(id: string): Promise<StoryWithPages | null> {
  const { data, error } = await supabase
    .from('story')
    .select('*, page(*)')
    .eq('id', id)
    .order('position', { referencedTable: 'page', ascending: true })
    .maybeSingle();
  if (error) throw error;
  return data;
}

/** Create a new (empty) story owned by the current user; `author_id` defaults to auth.uid(). */
export async function createStory(title: string): Promise<StoryRow> {
  const insert: TablesInsert<'story'> = { title };
  const { data, error } = await supabase.from('story').insert(insert).select('*').single();
  if (error) throw error;
  return data;
}

/** Patch a story's title / style / cover texture (only provided fields change). */
export async function updateStory(
  id: string,
  patch: { title?: string; style?: StoryStyle; coverTexture?: string },
): Promise<void> {
  const update: TablesUpdate<'story'> = {};
  if (patch.title !== undefined) update.title = patch.title;
  if (patch.style !== undefined) update.style = patch.style as Json;
  if (patch.coverTexture !== undefined) update.cover_texture = patch.coverTexture;
  const { error } = await supabase.from('story').update(update).eq('id', id);
  if (error) throw error;
}

export async function deleteStory(id: string): Promise<void> {
  const { error } = await supabase.from('story').delete().eq('id', id);
  if (error) throw error;
}

/** Append a page at `position` with optional text. */
export async function createPage(
  storyId: string,
  position: number,
  text = '',
): Promise<PageRow> {
  const insert: TablesInsert<'page'> = { story_id: storyId, position, text };
  const { data, error } = await supabase.from('page').insert(insert).select('*').single();
  if (error) throw error;
  return data;
}

export async function updatePage(
  id: string,
  patch: { text?: string; position?: number },
): Promise<void> {
  const update: TablesUpdate<'page'> = {};
  if (patch.text !== undefined) update.text = patch.text;
  if (patch.position !== undefined) update.position = patch.position;
  const { error } = await supabase.from('page').update(update).eq('id', id);
  if (error) throw error;
}

export async function deletePage(id: string): Promise<void> {
  const { error } = await supabase.from('page').delete().eq('id', id);
  if (error) throw error;
}

/**
 * Swap two adjacent pages. Uses a temporary position (-1) to dodge the
 * `unique(story_id, position)` constraint, exactly like the Flutter reorder.
 */
export async function swapPages(a: PageRow, b: PageRow): Promise<void> {
  await updatePage(a.id, { position: -1 });
  await updatePage(b.id, { position: a.position });
  await updatePage(a.id, { position: b.position });
}

/** Generate a Midjourney illustration for a page; returns the stored URL. */
export async function generateIllustration(
  pageId: string,
  prompt: string,
): Promise<string | null> {
  const { data, error } = await supabase.functions.invoke('generate-illustration', {
    body: { page_id: pageId, prompt },
  });
  if (error) throw await describeFunctionError(error);
  const url = (data as { illustration_url?: unknown })?.illustration_url;
  return typeof url === 'string' ? url : null;
}

/** Generate Deepgram narration for a page; returns the stored audio URL. */
export async function generateAudio(pageId: string, text?: string): Promise<string | null> {
  const body: Record<string, unknown> = { page_id: pageId };
  if (text != null) body.text = text;
  const { data, error } = await supabase.functions.invoke('generate-audio', { body });
  if (error) throw await describeFunctionError(error);
  const url = (data as { audio_url?: unknown })?.audio_url;
  return typeof url === 'string' ? url : null;
}

/** Generate a Midjourney cover texture for a story; returns the stored URL. */
export async function generateCoverTexture(
  storyId: string,
  prompt: string,
): Promise<string | null> {
  const { data, error } = await supabase.functions.invoke('generate-texture', {
    body: { story_id: storyId, prompt },
  });
  if (error) throw await describeFunctionError(error);
  const url = (data as { texture_url?: unknown })?.texture_url;
  return typeof url === 'string' ? url : null;
}

/**
 * Edge functions return their error detail in the response body (e.g.
 * `{ error: "Forbidden..." }`). `FunctionsHttpError` carries that body in
 * `.context` (a Response); surface its message instead of a bare "non-2xx".
 */
async function describeFunctionError(error: unknown): Promise<Error> {
  const ctx = (error as { context?: Response }).context;
  if (ctx && typeof ctx.json === 'function') {
    try {
      const body = await ctx.clone().json();
      if (body?.error) return new Error(String(body.error));
    } catch {
      /* fall through */
    }
  }
  return error instanceof Error ? error : new Error(String(error));
}
