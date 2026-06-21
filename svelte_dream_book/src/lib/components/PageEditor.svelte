<script lang="ts">
  import { updatePage } from '$lib/stories';
  import { generateIllustration, generateAudio } from '$lib/generation';
  import { toasts } from '$lib/toast.svelte';
  import ImageLightbox from '$lib/components/ImageLightbox.svelte';
  import type { PageRow } from '$lib/types';

  let {
    page,
    index,
    total,
    onChanged,
    onMoveUp,
    onMoveDown,
    onDelete
  }: {
    page: PageRow;
    index: number;
    total: number;
    onChanged: () => void | Promise<void>;
    onMoveUp: () => void;
    onMoveDown: () => void;
    onDelete: () => void;
  } = $props();

  // Local editable copies seeded from the initial prop values (intentional snapshots).
  // svelte-ignore state_referenced_locally
  let text = $state(page.text ?? '');
  // svelte-ignore state_referenced_locally
  let illustrationUrl = $state<string | null>(page.illustration_url);
  // svelte-ignore state_referenced_locally
  let audioUrl = $state<string | null>(page.audio_url);

  let savingText = $state(false);
  let generatingIllustration = $state(false);
  let generatingAudio = $state(false);

  // Illustration prompt dialog
  let showPrompt = $state(false);
  let promptText = $state('');

  let illustrationBroken = $state(false);
  let lightboxOpen = $state(false);

  function msg(e: unknown): string {
    return e instanceof Error ? e.message : String(e);
  }

  async function saveText() {
    savingText = true;
    try {
      await updatePage(page.id, { text });
      toasts.show('Page saved');
      await onChanged();
    } catch (e) {
      toasts.error('Failed to save page: ' + msg(e));
    } finally {
      savingText = false;
    }
  }

  function openIllustrationPrompt() {
    promptText = text;
    showPrompt = true;
  }

  async function confirmIllustration() {
    const prompt = promptText.trim();
    if (!prompt) {
      showPrompt = false;
      return;
    }
    showPrompt = false;
    generatingIllustration = true;
    illustrationBroken = false;
    try {
      const url = await generateIllustration(page.id, prompt);
      if (url) illustrationUrl = url;
      toasts.show('Illustration generated');
    } catch (e) {
      toasts.error('Illustration failed: ' + msg(e));
    } finally {
      generatingIllustration = false;
    }
  }

  async function makeAudio() {
    generatingAudio = true;
    try {
      const trimmed = text.trim();
      const url = await generateAudio(page.id, trimmed || undefined);
      if (url) audioUrl = url;
      toasts.show('Audio generated');
    } catch (e) {
      toasts.error('Audio failed: ' + msg(e));
    } finally {
      generatingAudio = false;
    }
  }
</script>

<div class="glass card">
  <div class="head">
    <span class="page-no">Page {index + 1}</span>
    <span class="spacer"></span>
    <button
      class="mz-btn-ghost icon"
      aria-label="Move page up"
      disabled={index === 0}
      onclick={onMoveUp}>▲</button
    >
    <button
      class="mz-btn-ghost icon"
      aria-label="Move page down"
      disabled={index === total - 1}
      onclick={onMoveDown}>▼</button
    >
    <button class="mz-btn-ghost icon" aria-label="Delete page" onclick={onDelete}>🗑</button>
  </div>

  <textarea class="mz-input area" rows="3" placeholder="Page text…" bind:value={text}></textarea>

  <div class="actions">
    <button class="mz-btn-outline" onclick={saveText} disabled={savingText}>
      {#if savingText}<span class="mz-spinner small"></span>{/if}
      Save text
    </button>
    <button
      class="mz-btn-outline"
      onclick={openIllustrationPrompt}
      disabled={generatingIllustration}
    >
      {#if generatingIllustration}<span class="mz-spinner small"></span>{/if}
      Generate illustration
    </button>
    <button class="mz-btn-outline" onclick={makeAudio} disabled={generatingAudio}>
      {#if generatingAudio}<span class="mz-spinner small"></span>{/if}
      Generate audio
    </button>
  </div>

  {#if illustrationUrl}
    <div class="illustration">
      {#if illustrationBroken}
        <div class="img-fallback">Couldn’t load illustration.</div>
      {:else}
        <button
          type="button"
          class="img-btn"
          aria-label="View illustration full size"
          onclick={() => (lightboxOpen = true)}
        >
          <img
            src={illustrationUrl}
            alt="Generated artwork for this page"
            onerror={() => {
              illustrationBroken = true;
            }}
          />
          <span class="zoom-hint" aria-hidden="true">⤢</span>
        </button>
      {/if}
    </div>
  {/if}

  {#if audioUrl}
    <div class="audio">
      <audio controls src={audioUrl}></audio>
      <span class="audio-url" title={audioUrl}>{audioUrl}</span>
    </div>
  {/if}
</div>

{#if lightboxOpen && illustrationUrl && !illustrationBroken}
  <ImageLightbox
    src={illustrationUrl}
    alt="Generated artwork for this page"
    onClose={() => (lightboxOpen = false)}
  />
{/if}

{#if showPrompt}
  <div class="backdrop" role="presentation" onclick={() => (showPrompt = false)}>
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div
      class="glass modal"
      role="dialog"
      aria-modal="true"
      aria-label="Illustration prompt"
      tabindex="-1"
      onclick={(e) => e.stopPropagation()}
    >
      <h2 class="modal-title">Illustration prompt</h2>
      <textarea
        class="mz-input area"
        rows="4"
        placeholder="Describe the illustration…"
        bind:value={promptText}
      ></textarea>
      <div class="modal-actions">
        <button class="mz-btn-ghost" onclick={() => (showPrompt = false)}>Cancel</button>
        <button class="mz-btn" onclick={confirmIllustration}>Generate</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .card {
    padding: 16px;
    border-radius: var(--radius-card);
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .head {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .page-no {
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 16px;
  }
  .spacer {
    flex: 1;
  }
  .icon {
    padding: 6px 10px;
    font-size: 14px;
  }
  .area {
    resize: vertical;
    min-height: 72px;
    font-family: var(--font-body);
    line-height: 1.5;
  }
  .actions {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }
  .actions .mz-btn-outline {
    display: inline-flex;
    align-items: center;
    gap: 8px;
  }
  .mz-spinner.small {
    width: 14px;
    height: 14px;
  }

  .img-btn {
    position: relative;
    display: block;
    width: 100%;
    padding: 0;
    border: none;
    background: none;
    border-radius: var(--radius-control);
    cursor: zoom-in;
    overflow: hidden;
  }
  .illustration img {
    width: 100%;
    max-height: 200px;
    object-fit: cover;
    border-radius: var(--radius-control);
    display: block;
  }
  .zoom-hint {
    position: absolute;
    top: 8px;
    right: 8px;
    width: 30px;
    height: 30px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    font-size: 15px;
    color: var(--color-ink);
    background: rgba(6, 9, 24, 0.55);
    opacity: 0;
    transition: opacity 0.15s ease;
  }
  .img-btn:hover .zoom-hint,
  .img-btn:focus-visible .zoom-hint {
    opacity: 1;
  }
  .img-fallback {
    padding: 24px;
    text-align: center;
    color: var(--color-ink-muted);
    border: 1px dashed color-mix(in srgb, var(--color-ink) 25%, transparent);
    border-radius: var(--radius-control);
  }

  .audio {
    display: flex;
    align-items: center;
    gap: 10px;
    min-width: 0;
  }
  .audio audio {
    flex: 0 0 auto;
    max-width: 60%;
  }
  .audio-url {
    flex: 1;
    min-width: 0;
    font-size: 12px;
    color: var(--color-ink-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .backdrop {
    position: fixed;
    inset: 0;
    z-index: 30;
    background: rgba(6, 9, 24, 0.6);
    backdrop-filter: blur(2px);
    display: grid;
    place-items: center;
    padding: 24px;
  }
  .modal {
    width: 100%;
    max-width: 420px;
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    border-radius: var(--radius-card);
  }
  .modal-title {
    font-family: var(--font-display);
    font-size: 22px;
    margin: 0;
  }
  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
  }
</style>
