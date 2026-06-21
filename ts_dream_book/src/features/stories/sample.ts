import type { Json } from '../../lib/database.types';
import type { StoryWithPages } from './types';

/**
 * Local sample stories so the reader runs with zero backend/auth. Shaped exactly
 * like the Supabase payload (`StoryWithPages`) so swapping in `getStoryWithPages`
 * later is a drop-in. Illustrations are left null on purpose — the reader renders
 * an on-theme gradient placeholder when a page has no `illustration_url`.
 */
function page(
  storyId: string,
  position: number,
  text: string,
): StoryWithPages['page'][number] {
  return {
    id: `${storyId}-p${position}`,
    story_id: storyId,
    position,
    text,
    audio_url: null,
    illustration_url: null,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    created_by: null,
    updated_by: null,
  };
}

function story(
  id: string,
  title: string,
  style: Json,
  texts: string[],
): StoryWithPages {
  return {
    id,
    title,
    cover_texture: null,
    author_id: 'sample',
    style,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    created_by: null,
    updated_by: null,
    page: texts.map((t, i) => page(id, i, t)),
  };
}

export const SAMPLE_STORIES: StoryWithPages[] = [
  story(
    'sample-moon',
    'The Moon Who Lost Her Glow',
    { backgroundColor: '#fdfaf3', textColor: '#2a2433', fontSizeScale: 1.05 },
    [
      'High above the sleeping village, the Moon noticed her silver light had grown thin and pale, like a candle nearing its end.',
      '“Where has my glow gone?” she whispered to the wandering clouds. But the clouds only drifted by, yawning, on their way to bed.',
      'A small owl with lantern eyes fluttered up beside her. “Perhaps,” he hooted softly, “you have been giving your light away all along.”',
      'And so the Moon looked down — and saw a thousand windows glowing warm, a thousand dreams she had quietly lit, one night at a time.',
      'She smiled, and in that smile her glow returned, brighter than before. For light, she learned, grows the more it is shared.',
    ],
  ),
  story(
    'sample-fox',
    'A Lantern for the Little Fox',
    { backgroundColor: '#fbf6ec', textColor: '#33243a', fontSizeScale: 1.0 },
    [
      'When the autumn fog rolled into the Whispering Wood, the little fox could not find her way back to her den.',
      'Then, between the birch trees, a firefly blinked — once, twice — offering to be her lantern through the dark.',
      'Together they wove past silver puddles and over root and stone, the tiny light always one hop ahead.',
      'At last her den glowed gold before her. “Stay,” said the fox. And the firefly did, curling like a star upon her pillow.',
    ],
  ),
];

export function findSampleStory(id: string): StoryWithPages | undefined {
  return SAMPLE_STORIES.find((s) => s.id === id);
}
