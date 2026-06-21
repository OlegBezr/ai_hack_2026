<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { page } from '$app/state';
  import { resolve } from '$app/paths';
  import { goto } from '$app/navigation';
  import Book from '$lib/components/Book.svelte';
  import NarrationBar from '$lib/components/NarrationBar.svelte';
  import { getStory } from '$lib/stories';
  import { parseStyle, type StoryWithPages, type StoryStyle } from '$lib/types';
  import { Narration } from '$lib/audio/narration.svelte';
  import { backgroundMusic } from '$lib/audio/background-music.svelte';

  let story = $state<StoryWithPages | null>(null);
  let style = $state<StoryStyle | null>(null);
  let loading = $state(true);
  let error = $state<string | null>(null);

  let controls = $state<{ next: () => void; prev: () => void } | null>(null);

  const narration = new Narration();

  /**
   * Map the Book's left-leaf index to a story page and load its narration.
   * Spread layout: leaf 0 = cover; each story page is the spread [text, art] at
   * left leaves 1, 3, 5, …; the trailing blank / "The End" / back cover carry no
   * narration.
   */
  function handleFlip(leftLeaf: number): void {
    if (!story) return;
    if (leftLeaf <= 0) {
      void narration.openPage(null); // cover
      return;
    }
    const pageIndex = (leftLeaf - 1) / 2;
    if (Number.isInteger(pageIndex) && pageIndex >= 0 && pageIndex < story.page.length) {
      void narration.openPage(story.page[pageIndex].audio_url);
    } else {
      void narration.openPage(null); // blank / The End / back cover
    }
  }

  onMount(async () => {
    backgroundMusic.pause(); // reading is silent

    const id = page.params.id;
    if (!id) {
      error = 'No story id in the URL.';
      loading = false;
      return;
    }
    try {
      story = await getStory(id);
      if (story) {
        story.page.sort((a, b) => a.position - b.position);
        style = parseStyle(story.style);
      } else {
        error = 'Story not found (or not yours to read).';
      }
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    }
    loading = false;
  });

  onDestroy(() => {
    narration.dispose();
    backgroundMusic.ensureStarted(); // resume (respects mute state)
  });
</script>

<main class="reader">
  <header class="topbar">
    <a class="close" href={resolve('/')} aria-label="Close reader">✕</a>
    {#if story}
      <h1 class="title">{story.title}</h1>
    {/if}
  </header>

  {#if loading}
    <div class="state">
      <span class="mz-spinner"></span>
      <p class="muted">Turning to the first page…</p>
    </div>
  {:else if error}
    <div class="state">
      <p class="error">{error}</p>
      <button class="mz-btn" onclick={() => goto(resolve('/'))}>Back</button>
    </div>
  {:else if story && style}
    <div class="stage">
      <Book
        title={story.title}
        coverTexture={story.cover_texture}
        pages={story.page}
        {style}
        oninit={(api) => (controls = api)}
        onflip={handleFlip}
      />
    </div>

    <NarrationBar {narration} />

    <div class="nav">
      <button onclick={() => controls?.prev()} aria-label="Previous page">‹</button>
      <button onclick={() => controls?.next()} aria-label="Next page">›</button>
    </div>
    <p class="hint">Drag a page corner — or tap the arrows.</p>
  {/if}
</main>

<style>
  .reader {
    position: relative;
    z-index: 1;
    height: 100dvh;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 16px;
    gap: 14px;
  }
  .topbar {
    align-self: stretch;
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .close {
    flex: 0 0 auto;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    border-radius: 50%;
    color: var(--color-lilac);
    text-decoration: none;
    font-size: 18px;
    border: 1px solid color-mix(in srgb, var(--color-lilac) 30%, transparent);
    background: color-mix(in srgb, var(--color-night-top) 50%, transparent);
  }
  .title {
    flex: 1 1 auto;
    margin: 0;
    font-family: var(--font-display);
    font-size: clamp(18px, 3vw, 26px);
    color: var(--color-ink);
    text-align: center;
    padding-right: 36px; /* balance the close button */
  }
  .stage {
    width: 100%;
    flex: 1 1 auto;
    min-height: 0; /* let the stage actually shrink inside the 100dvh column */
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 4px 0;
  }
  /* Fit the book into the leftover space between the top bar and the controls.
     The spread is two 400×560 pages → aspect 10/7; matching that here means the
     book is bounded by BOTH the stage height (height: 100%) and width
     (max-width), so it never grows into the narration bar / controls and is
     never clipped — it just letterboxes. `!important` overrides StPageFlip's
     inline min-height on the book element. */
  .stage :global(.book) {
    width: 100%;
    max-width: 1000px;
    max-height: 100%;
    aspect-ratio: 10 / 7;
    min-height: 0 !important;
    margin: 0 auto;
  }
  .state {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 16px;
  }
  .muted {
    color: var(--color-ink-muted);
  }
  .error {
    color: var(--color-danger);
  }
  .nav {
    display: flex;
    gap: 16px;
  }
  .nav button {
    width: 56px;
    height: 44px;
    font-size: 22px;
    border-radius: var(--radius-control);
    border: 1px solid color-mix(in srgb, var(--color-lilac) 35%, transparent);
    background: color-mix(in srgb, var(--color-surface) 70%, transparent);
    color: var(--color-gold);
    cursor: pointer;
    backdrop-filter: blur(8px);
  }
  .nav button:active {
    transform: scale(0.96);
  }
  .hint {
    color: var(--color-ink-muted);
    font-size: 13px;
    margin: 0;
  }
</style>
