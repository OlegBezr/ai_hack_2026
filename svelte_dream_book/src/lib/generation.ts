import { supabase } from './supabase';
import type { StoryStyle } from './types';

/**
 * Thin client for the three Supabase edge functions that drive AI generation —
 * the same functions the Flutter app calls. `functions.invoke` automatically
 * attaches the signed-in user's bearer token, which each function uses to
 * verify story ownership before calling Midjourney / Deepgram and stamping the
 * result back onto the row.
 *
 * Note: illustration/texture generation can block for tens of seconds while
 * Midjourney renders. Callers should show a spinner.
 */

function unwrap<T>(data: unknown, error: unknown): T {
  if (error) {
    // Edge-function errors surface as a FunctionsHttpError; try to read the body.
    const e = error as { message?: string; context?: { error?: string } };
    throw new Error(e.context?.error ?? e.message ?? 'Generation failed');
  }
  const d = data as { error?: string } & T;
  if (d && typeof d === 'object' && 'error' in d && d.error) {
    throw new Error(d.error);
  }
  return d as T;
}

/** Generate a page illustration (Midjourney). Returns the first image URL. */
export async function generateIllustration(pageId: string, prompt: string): Promise<string | null> {
  const { data, error } = await supabase.functions.invoke('generate-illustration', {
    body: { page_id: pageId, prompt }
  });
  const res = unwrap<{ illustration_url?: string; images?: string[] }>(data, error);
  return res.illustration_url ?? null;
}

/** Generate a story cover texture (Midjourney). Returns the texture URL. */
export async function generateCoverTexture(
  storyId: string,
  prompt: string
): Promise<string | null> {
  const { data, error } = await supabase.functions.invoke('generate-texture', {
    body: { story_id: storyId, prompt }
  });
  const res = unwrap<{ texture_url?: string; images?: string[] }>(data, error);
  return res.texture_url ?? null;
}

/** One page returned by `compose-story`, with its (transient) illustration prompt. */
export interface ComposedPage {
  id: string;
  position: number;
  text: string;
  illustration_prompt: string;
}

/** Result of `compose-story`: a freshly created story plus per-page prompts so
 *  the caller can fan out illustration/audio/cover generation. Mirrors the
 *  Flutter `ComposedStoryResult`. */
export interface ComposedStory {
  story_id: string;
  title: string;
  cover_prompt: string;
  style?: StoryStyle;
  pages: ComposedPage[];
}

/**
 * Compose a full storybook from a spoken/typed [transcript]: Claude splits it
 * into ordered pages (each with an illustration prompt), picks a title + cover
 * prompt, and the story + pages are persisted. Media is NOT generated here —
 * fan out {@link generateAudio} / {@link generateIllustration} /
 * {@link generateCoverTexture} afterwards.
 */
export async function composeStory(
  transcript: string,
  opts: { title?: string; pageCount?: number } = {}
): Promise<ComposedStory> {
  const body: Record<string, unknown> = { transcript };
  if (opts.title?.trim()) body.title = opts.title.trim();
  if (opts.pageCount) body.page_count = opts.pageCount;

  const { data, error } = await supabase.functions.invoke('compose-story', { body });
  const res = unwrap<ComposedStory>(data, error);
  if (!res?.story_id) throw new Error('compose-story returned an unexpected response');
  return res;
}

/** Generate narration audio (Deepgram TTS). Returns the audio URL. */
export async function generateAudio(pageId: string, text?: string): Promise<string | null> {
  const body: Record<string, unknown> = { page_id: pageId };
  if (text) body.text = text;
  const { data, error } = await supabase.functions.invoke('generate-audio', { body });
  const res = unwrap<{ audio_url?: string }>(data, error);
  return res.audio_url ?? null;
}

/**
 * Mint a short-lived Deepgram token for the live Voice Agent WebSocket. The
 * long-lived key stays server-side; this edge function exchanges it for an
 * ephemeral token gated by the signed-in user. Returns the token and its TTL.
 */
export async function getVoiceAgentToken(): Promise<{ token: string; expiresIn: number }> {
  const { data, error } = await supabase.functions.invoke('voice-agent-token', { body: {} });
  const res = unwrap<{ token?: string; expires_in?: number }>(data, error);
  if (!res.token) throw new Error('No voice token returned');
  return { token: res.token, expiresIn: res.expires_in ?? 60 };
}
