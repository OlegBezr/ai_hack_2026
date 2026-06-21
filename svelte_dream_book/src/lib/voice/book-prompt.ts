import type { StoryWithPages } from '$lib/types';

/**
 * Build the agent's system prompt: instructions plus the full text of every
 * page, so the LLM can answer about the book without any retrieval. Port of
 * Flutter's `buildBookSystemPrompt`.
 */
export function buildBookSystemPrompt(story: StoryWithPages): string {
  const lines: string[] = [
    'You are a warm, playful companion helping a reader talk about a ' +
      'storybook they just read. Speak in short, natural spoken sentences ' +
      '(usually 1-3 at a time), as if chatting aloud. Use ONLY the story below ' +
      'as your source of truth about its plot, characters, and details; if ' +
      'asked about something not in it, say so kindly — you may imagine gently ' +
      'if invited. Do not read the whole story back unless asked.',
    '',
    `=== STORYBOOK: "${story.title}" ===`
  ];

  const pages = [...story.page].sort((a, b) => a.position - b.position);
  if (pages.length === 0) {
    lines.push('(This story has no pages yet.)');
  } else {
    pages.forEach((page, i) => {
      const text = (page.text ?? '').trim();
      if (text) lines.push(`Page ${i + 1}: ${text}`);
    });
  }
  lines.push('=== END OF STORYBOOK ===');
  return lines.join('\n');
}

/** The agent's opening spoken line for a story. */
export function buildGreeting(story: StoryWithPages): string {
  return `Hi! I just read "${story.title}" with you. What would you like to talk about?`;
}
