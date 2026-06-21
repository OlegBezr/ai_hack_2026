<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import { resolve } from '$app/paths';
  import { goto } from '$app/navigation';
  import { getStory, updateStory, createPage, deletePage, swapPagePositions } from '$lib/stories';
  import { generateCoverTexture } from '$lib/generation';
  import { toasts } from '$lib/toast.svelte';
  import {
    parseStyle,
    FONT_OPTIONS,
    ALIGN_OPTIONS,
    fontStack,
    READER_DEFAULTS,
    type StoryStyle,
    type StoryWithPages,
    type FontFamily,
    type TextAlign
  } from '$lib/types';
  import PageEditor from '$lib/components/PageEditor.svelte';
  import ColorPicker from '$lib/components/ColorPicker.svelte';
  import ImageLightbox from '$lib/components/ImageLightbox.svelte';

  const id = page.params.id;

  let story = $state<StoryWithPages | null>(null);
  let loading = $state(true);
  let error = $state<string | null>(null);

  let title = $state('');
  let style = $state<StoryStyle>({});

  let savingTitle = $state(false);
  let savingStyle = $state(false);
  let generatingCover = $state(false);
  let addingPage = $state(false);

  let stylePanelOpen = $state(true);

  // Cover prompt dialog
  let showCoverPrompt = $state(false);
  let coverPrompt = $state('');

  // Cover full-size viewer
  let coverLightboxOpen = $state(false);

  // Delete-page confirm dialog
  let pendingDeletePage = $state<{ id: string; index: number } | null>(null);
  let deletingPage = $state(false);

  const pages = $derived(story?.page ?? []);
  const sizeScale = $derived(style.fontSizeScale ?? 1.0);

  function msg(e: unknown): string {
    return e instanceof Error ? e.message : String(e);
  }

  async function load() {
    if (!id) {
      error = 'No story id in the URL.';
      loading = false;
      return;
    }
    loading = true;
    error = null;
    try {
      const s = await getStory(id);
      if (!s) {
        error = 'Story not found.';
      } else {
        story = s;
        title = s.title;
        style = parseStyle(s.style);
      }
    } catch (e) {
      error = msg(e);
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    void load();
  });

  /* ── Title ───────────────────────────────────────────────────────────── */
  async function saveTitle() {
    if (!id) return;
    const next = title.trim();
    if (!next || next === story?.title) return;
    savingTitle = true;
    try {
      await updateStory(id, { title: next });
      if (story) story.title = next;
      toasts.show('Title saved');
    } catch (e) {
      toasts.error('Failed to save title: ' + msg(e));
    } finally {
      savingTitle = false;
    }
  }

  /* ── Cover ───────────────────────────────────────────────────────────── */
  function openCoverPrompt() {
    coverPrompt = story?.title ?? '';
    showCoverPrompt = true;
  }

  async function confirmCover() {
    if (!id) return;
    const prompt = coverPrompt.trim();
    if (!prompt) {
      showCoverPrompt = false;
      return;
    }
    showCoverPrompt = false;
    generatingCover = true;
    try {
      await generateCoverTexture(id, prompt);
      await load();
      toasts.show('Cover texture generated');
    } catch (e) {
      toasts.error('Cover generation failed: ' + msg(e));
    } finally {
      generatingCover = false;
    }
  }

  /* ── Style ───────────────────────────────────────────────────────────── */
  async function applyStyle(next: StoryStyle) {
    if (!id) return;
    style = next;
    savingStyle = true;
    try {
      await updateStory(id, { style: next });
      if (story) story.style = next as StoryWithPages['style'];
      toasts.show('Style saved');
    } catch (e) {
      toasts.error('Failed to save style: ' + msg(e));
    } finally {
      savingStyle = false;
    }
  }

  function setFont(value: FontFamily | null) {
    void applyStyle({ ...style, fontFamily: value });
  }

  function setAlign(value: TextAlign) {
    void applyStyle({ ...style, textAlign: value });
  }

  function setTextColor(hex: string | null) {
    void applyStyle({ ...style, textColor: hex });
  }

  function setBackgroundColor(hex: string | null) {
    void applyStyle({ ...style, backgroundColor: hex });
  }

  // Slider: live preview on input, persist on change-end.
  function onSizeInput(e: Event) {
    const v = Number((e.currentTarget as HTMLInputElement).value);
    style = { ...style, fontSizeScale: v };
  }

  function onSizeCommit(e: Event) {
    const v = Number((e.currentTarget as HTMLInputElement).value);
    void applyStyle({ ...style, fontSizeScale: v });
  }

  /* ── Pages ───────────────────────────────────────────────────────────── */
  async function addPage() {
    if (!id) return;
    addingPage = true;
    try {
      const nextPos = pages.length ? Math.max(...pages.map((p) => p.position)) + 1 : 0;
      await createPage(id, nextPos, '');
      await load();
    } catch (e) {
      toasts.error('Failed to add page: ' + msg(e));
    } finally {
      addingPage = false;
    }
  }

  async function movePage(index: number, dir: -1 | 1) {
    const target = index + dir;
    if (target < 0 || target >= pages.length) return;
    try {
      await swapPagePositions(pages[index], pages[target]);
      await load();
    } catch (e) {
      toasts.error('Failed to reorder: ' + msg(e));
    }
  }

  function requestDeletePage(index: number) {
    const p = pages[index];
    if (p) pendingDeletePage = { id: p.id, index };
  }

  async function confirmDeletePage() {
    const target = pendingDeletePage;
    if (!target) return;
    deletingPage = true;
    try {
      await deletePage(target.id);
      pendingDeletePage = null;
      await load();
    } catch (e) {
      toasts.error('Failed to delete page: ' + msg(e));
    } finally {
      deletingPage = false;
    }
  }

  // Live preview resolved style.
  const previewBg = $derived(style.backgroundColor ?? '#FFF8E7');
  const previewColor = $derived(style.textColor ?? READER_DEFAULTS.textColor);
  const previewFont = $derived(fontStack(style.fontFamily));
  const previewSize = $derived(READER_DEFAULTS.baseFontPx * sizeScale);
  const previewAlign = $derived(style.textAlign ?? READER_DEFAULTS.textAlign);
</script>

<div class="page">
  <header class="topbar">
    <button class="back" onclick={() => goto(resolve('/'))}>‹ Library</button>
    <h1 class="bar-title">Edit story</h1>
    {#if id}
      <a class="read" href={resolve('/read/[id]', { id })}>Read ▸</a>
    {:else}
      <span class="read disabled">Read ▸</span>
    {/if}
  </header>

  {#if loading}
    <div class="state">
      <span class="mz-spinner"></span>
      <p class="state-text">Opening the manuscript…</p>
    </div>
  {:else if error}
    <div class="state">
      <p class="state-error">{error}</p>
      <button class="mz-btn" onclick={() => load()}>Retry</button>
    </div>
  {:else if story}
    <!-- Title -->
    <section class="block">
      <div class="title-row">
        <input
          class="mz-input"
          bind:value={title}
          placeholder="Story title"
          aria-label="Story title"
          onkeydown={(e) => {
            if (e.key === 'Enter') void saveTitle();
          }}
        />
        <button class="mz-btn" onclick={saveTitle} disabled={savingTitle}>
          {#if savingTitle}<span class="mz-spinner small"></span>{/if}
          Save
        </button>
      </div>
    </section>

    <!-- Cover -->
    <section class="block">
      <p class="mz-section-label">Cover</p>
      {#if story.cover_texture}
        <button
          type="button"
          class="cover-btn"
          aria-label="View cover full size"
          onclick={() => (coverLightboxOpen = true)}
        >
          <img class="cover" src={story.cover_texture} alt="Story cover texture" />
          <span class="zoom-hint" aria-hidden="true">⤢</span>
        </button>
      {/if}
      <button class="mz-btn-outline" onclick={openCoverPrompt} disabled={generatingCover}>
        {#if generatingCover}<span class="mz-spinner small"></span>{/if}
        Generate cover texture
      </button>
    </section>

    <!-- Page text style -->
    <section class="block glass style-panel">
      <button
        class="panel-head"
        aria-expanded={stylePanelOpen}
        onclick={() => (stylePanelOpen = !stylePanelOpen)}
      >
        <div class="panel-head-text">
          <span class="panel-title">Page text style</span>
          <span class="panel-sub">Applies to all pages</span>
        </div>
        {#if savingStyle}<span class="mz-spinner small"></span>{/if}
        <span class="chevron" class:open={stylePanelOpen}>▾</span>
      </button>

      {#if stylePanelOpen}
        <div class="panel-body">
          <!-- Font family -->
          <label class="field">
            <span class="field-label">Font family</span>
            <select
              class="mz-input"
              value={style.fontFamily ?? ''}
              onchange={(e) => {
                const v = (e.currentTarget as HTMLSelectElement).value;
                setFont(v === '' ? null : (v as FontFamily));
              }}
            >
              {#each FONT_OPTIONS as opt (opt.label)}
                <option value={opt.value ?? ''}>{opt.label}</option>
              {/each}
            </select>
          </label>

          <!-- Size -->
          <div class="field">
            <span class="field-label"
              >Size <span class="size-val">{sizeScale.toFixed(2)}</span></span
            >
            <input
              type="range"
              min="0.8"
              max="2.0"
              step="0.1"
              value={sizeScale}
              oninput={onSizeInput}
              onchange={onSizeCommit}
            />
          </div>

          <!-- Text align -->
          <div class="field">
            <span class="field-label">Text align</span>
            <div class="segmented">
              {#each ALIGN_OPTIONS as opt (opt.value)}
                <button
                  type="button"
                  class="seg"
                  class:active={(style.textAlign ?? 'left') === opt.value}
                  onclick={() => setAlign(opt.value)}
                >
                  {opt.label}
                </button>
              {/each}
            </div>
          </div>

          <!-- Colors -->
          <ColorPicker
            label="Text color"
            selected={style.textColor ?? null}
            onPick={setTextColor}
          />
          <ColorPicker
            label="Page background"
            selected={style.backgroundColor ?? null}
            onPick={setBackgroundColor}
          />

          <!-- Preview -->
          <div class="field">
            <span class="field-label">Preview</span>
            <div
              class="preview"
              style:background={previewBg}
              style:color={previewColor}
              style:font-family={previewFont}
              style:font-size={`${previewSize}px`}
              style:text-align={previewAlign}
            >
              Once upon a time, in a land far away…
            </div>
          </div>
        </div>
      {/if}
    </section>

    <!-- Pages -->
    <section class="block">
      <p class="mz-section-label">Pages</p>
      {#if pages.length === 0}
        <p class="state-text">No pages yet. Add one below.</p>
      {:else}
        <div class="pages">
          {#each pages as p, i (p.id)}
            <PageEditor
              page={p}
              index={i}
              total={pages.length}
              onChanged={load}
              onMoveUp={() => movePage(i, -1)}
              onMoveDown={() => movePage(i, 1)}
              onDelete={() => requestDeletePage(i)}
            />
          {/each}
        </div>
      {/if}
    </section>
  {/if}

  <button
    class="fab"
    onclick={addPage}
    disabled={addingPage || loading || !!error}
    aria-label="Add page"
  >
    {#if addingPage}<span class="mz-spinner small"></span>{/if}
    ✚ Add page
  </button>
</div>

{#if coverLightboxOpen && story?.cover_texture}
  <ImageLightbox
    src={story.cover_texture}
    alt="Story cover texture"
    onClose={() => (coverLightboxOpen = false)}
  />
{/if}

{#if showCoverPrompt}
  <div class="backdrop" role="presentation" onclick={() => (showCoverPrompt = false)}>
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div
      class="glass modal"
      role="dialog"
      aria-modal="true"
      aria-label="Cover texture prompt"
      tabindex="-1"
      onclick={(e) => e.stopPropagation()}
    >
      <h2 class="modal-title">Cover texture prompt</h2>
      <textarea
        class="mz-input area"
        rows="4"
        placeholder="Describe the cover texture…"
        bind:value={coverPrompt}
      ></textarea>
      <div class="modal-actions">
        <button class="mz-btn-ghost" onclick={() => (showCoverPrompt = false)}>Cancel</button>
        <button class="mz-btn" onclick={confirmCover}>Generate</button>
      </div>
    </div>
  </div>
{/if}

{#if pendingDeletePage}
  <div
    class="backdrop"
    role="presentation"
    onclick={() => {
      if (!deletingPage) pendingDeletePage = null;
    }}
  >
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div
      class="glass modal"
      role="dialog"
      aria-modal="true"
      aria-label="Delete page"
      tabindex="-1"
      onclick={(e) => e.stopPropagation()}
    >
      <h2 class="modal-title">Delete page?</h2>
      <p class="modal-body">Page {pendingDeletePage.index + 1} will be removed.</p>
      <div class="modal-actions">
        <button
          class="mz-btn-ghost"
          onclick={() => (pendingDeletePage = null)}
          disabled={deletingPage}
        >
          Cancel
        </button>
        <button class="mz-btn danger" onclick={confirmDeletePage} disabled={deletingPage}>
          {deletingPage ? 'Deleting…' : 'Delete'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .page {
    position: relative;
    z-index: 1;
    max-width: 760px;
    margin: 0 auto;
    padding: 24px 20px 110px;
    display: flex;
    flex-direction: column;
    gap: 22px;
  }

  .topbar {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .back {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--color-lilac);
    font-weight: 600;
    font-size: 15px;
    padding: 6px 4px;
  }
  .bar-title {
    flex: 1;
    text-align: center;
    font-family: var(--font-display);
    font-weight: 700;
    font-size: clamp(20px, 4vw, 28px);
    margin: 0;
    text-shadow: 0 0 20px rgba(244, 199, 102, 0.22);
  }
  .read {
    color: var(--color-gold);
    text-decoration: none;
    font-weight: 600;
    font-size: 15px;
    padding: 6px 4px;
  }
  .read.disabled {
    color: var(--color-ink-muted);
    pointer-events: none;
  }

  .state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    padding: 72px 24px;
    text-align: center;
  }
  .state-text {
    color: var(--color-ink-muted);
    margin: 0;
  }
  .state-error {
    color: var(--color-danger);
    margin: 0;
  }

  .block {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .title-row {
    display: flex;
    gap: 10px;
    align-items: stretch;
  }
  .title-row .mz-input {
    flex: 1;
  }
  .mz-btn,
  .mz-btn-outline {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    white-space: nowrap;
  }
  .mz-spinner.small {
    width: 14px;
    height: 14px;
  }

  .cover-btn {
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
  .cover {
    max-height: 160px;
    width: 100%;
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
  .cover-btn:hover .zoom-hint,
  .cover-btn:focus-visible .zoom-hint {
    opacity: 1;
  }

  /* Style panel */
  .style-panel {
    border-radius: var(--radius-card);
    overflow: hidden;
    gap: 0;
  }
  .panel-head {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 16px;
    background: none;
    border: none;
    cursor: pointer;
    text-align: left;
    color: inherit;
  }
  .panel-head-text {
    flex: 1;
    display: flex;
    flex-direction: column;
  }
  .panel-title {
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 18px;
  }
  .panel-sub {
    font-size: 12px;
    color: var(--color-ink-muted);
  }
  .chevron {
    transition: transform 0.18s ease;
    color: var(--color-ink-muted);
  }
  .chevron.open {
    transform: rotate(180deg);
  }
  .panel-body {
    display: flex;
    flex-direction: column;
    gap: 18px;
    padding: 4px 16px 18px;
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .field-label {
    font-size: 13px;
    color: var(--color-ink-muted);
  }
  .field input[type='range'] {
    accent-color: var(--color-gold);
  }
  .size-val {
    color: var(--color-gold);
    font-variant-numeric: tabular-nums;
    margin-left: 6px;
  }

  .segmented {
    display: flex;
    gap: 6px;
  }
  .seg {
    flex: 1;
    padding: 8px 6px;
    font-size: 13px;
    border-radius: var(--radius-control);
    border: 1px solid color-mix(in srgb, var(--color-lilac) 30%, transparent);
    background: color-mix(in srgb, var(--color-surface) 50%, transparent);
    color: var(--color-ink);
    cursor: pointer;
    transition:
      background 0.15s ease,
      border-color 0.15s ease;
  }
  .seg.active {
    border-color: var(--color-gold);
    background: color-mix(in srgb, var(--color-gold) 20%, transparent);
    color: var(--color-gold);
  }

  .preview {
    border-radius: var(--radius-control);
    padding: 18px;
    line-height: 1.5;
    border: 1px solid color-mix(in srgb, var(--color-ink) 12%, transparent);
  }

  .pages {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .fab {
    position: fixed;
    right: 24px;
    bottom: 24px;
    z-index: 5;
    display: inline-flex;
    align-items: center;
    gap: 8px;
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 15px;
    padding: 14px 22px;
    border: none;
    border-radius: 999px;
    color: #2a1b05;
    background: radial-gradient(circle at 30% 30%, var(--color-gold), var(--color-amber));
    box-shadow: 0 10px 30px rgba(232, 169, 75, 0.45);
    cursor: pointer;
    transition:
      transform 0.18s ease,
      box-shadow 0.18s ease;
  }
  .fab:hover:not(:disabled) {
    transform: translateY(-3px);
    box-shadow: 0 14px 38px rgba(232, 169, 75, 0.55);
  }
  .fab:disabled {
    opacity: 0.6;
    cursor: default;
  }

  .backdrop {
    position: fixed;
    inset: 0;
    z-index: 20;
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
  .modal-body {
    margin: 0;
    color: var(--color-ink-muted);
  }
  .area {
    resize: vertical;
    min-height: 96px;
    font-family: var(--font-body);
    line-height: 1.5;
  }
  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
  }
  .mz-btn.danger {
    background: var(--color-danger);
    color: #fff;
  }
</style>
