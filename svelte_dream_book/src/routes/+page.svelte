<script lang="ts">
  import { onMount } from 'svelte';
  import { resolve } from '$app/paths';
  import { goto } from '$app/navigation';
  import { auth } from '$lib/auth.svelte';
  import { listStories, createStory, deleteStory } from '$lib/stories';
  import { fetchMyProfile } from '$lib/profile';
  import { toasts } from '$lib/toast.svelte';
  import type { StoryWithPages } from '$lib/types';
  import GlassCard from '$lib/components/GlassCard.svelte';
  import MagicWordmark from '$lib/components/MagicWordmark.svelte';

  let stories = $state<StoryWithPages[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);
  let profileName = $state<string | null>(null);

  // New-story dialog
  let showNew = $state(false);
  let newTitle = $state('New story');
  let creating = $state(false);

  // Delete dialog
  let pendingDelete = $state<StoryWithPages | null>(null);
  let deleting = $state(false);

  const avatarInitial = $derived(
    (profileName ?? auth.user?.email ?? '?').trim().charAt(0).toUpperCase() || '?'
  );

  function msg(e: unknown): string {
    return e instanceof Error ? e.message : String(e);
  }

  async function load() {
    loading = true;
    error = null;
    try {
      stories = await listStories();
    } catch (e) {
      error = msg(e);
    } finally {
      loading = false;
    }
  }

  async function loadProfile() {
    try {
      const p = await fetchMyProfile();
      profileName = p?.name ?? null;
    } catch {
      profileName = null;
    }
  }

  onMount(() => {
    void load();
    void loadProfile();
  });

  function openNew() {
    newTitle = 'New story';
    showNew = true;
  }

  async function confirmNew() {
    const title = newTitle.trim();
    if (!title) {
      showNew = false;
      return;
    }
    creating = true;
    try {
      const story = await createStory(title);
      showNew = false;
      await goto(resolve('/stories/[id]', { id: story.id }));
    } catch (e) {
      toasts.error('Failed to create story: ' + msg(e));
    } finally {
      creating = false;
    }
  }

  function requestDelete(story: StoryWithPages) {
    pendingDelete = story;
  }

  async function confirmDelete() {
    const story = pendingDelete;
    if (!story) return;
    deleting = true;
    try {
      await deleteStory(story.id);
      pendingDelete = null;
      await load();
    } catch (e) {
      toasts.error('Failed to delete story: ' + msg(e));
    } finally {
      deleting = false;
    }
  }

  async function signOut() {
    await auth.signOut();
  }
</script>

<div class="page">
  <header class="toolbar">
    <h1 class="title">My Stories</h1>
    <div class="actions">
      <a class="avatar" href={resolve('/profile')} aria-label="Profile">{avatarInitial}</a>
      <button class="mz-btn-outline" onclick={() => load()} disabled={loading}>Refresh</button>
      <button class="mz-btn-ghost" onclick={signOut}>Sign out</button>
    </div>
  </header>

  <p class="mz-section-label"><MagicWordmark /></p>

  {#if loading}
    <div class="state">
      <span class="mz-spinner"></span>
      <p class="state-text">Opening the library…</p>
    </div>
  {:else if error}
    <div class="state">
      <p class="state-error">{error}</p>
      <button class="mz-btn" onclick={() => load()}>Retry</button>
    </div>
  {:else if stories.length === 0}
    <div class="state empty">
      <div class="empty-glyph">✦</div>
      <h2 class="empty-title">Your library awaits</h2>
      <p class="state-text">Speak a story aloud and watch it become an illustrated book.</p>
      <button class="mz-btn" onclick={() => goto(resolve('/create'))}>🎙 Tell a story</button>
    </div>
  {:else}
    <ul class="grid">
      {#each stories as story (story.id)}
        <li>
          <GlassCard
            padding="0"
            class="story-card"
            onclick={() => goto(resolve('/stories/[id]', { id: story.id }))}
          >
            <div
              class="cover"
              style:background-image={story.cover_texture
                ? `url(${story.cover_texture})`
                : 'linear-gradient(160deg,#1a1340,#2c1b4d)'}
            >
              <span class="cover-title">{story.title}</span>
            </div>
            <div class="meta">
              <span class="meta-count"
                >{story.page.length} page{story.page.length === 1 ? '' : 's'}</span
              >
              <div class="meta-actions">
                <button
                  class="mz-btn-outline meta-btn"
                  onclick={(e) => {
                    e.stopPropagation();
                    void goto(resolve('/read/[id]', { id: story.id }));
                  }}
                >
                  Read
                </button>
                <button
                  class="mz-btn-ghost meta-btn icon"
                  aria-label="Delete story"
                  onclick={(e) => {
                    e.stopPropagation();
                    requestDelete(story);
                  }}
                >
                  🗑
                </button>
              </div>
            </div>
          </GlassCard>
        </li>
      {/each}
    </ul>
  {/if}

  <div class="fab-stack">
    <button class="fab tell" onclick={() => goto(resolve('/create'))} aria-label="Tell a story">
      🎙 Tell a story
    </button>
    <button class="fab" onclick={openNew} aria-label="New story">✦ New story</button>
  </div>
</div>

{#if showNew}
  <div
    class="backdrop"
    role="presentation"
    onclick={() => {
      if (!creating) showNew = false;
    }}
  >
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div
      class="glass modal"
      role="dialog"
      aria-modal="true"
      aria-label="New story"
      tabindex="-1"
      onclick={(e) => e.stopPropagation()}
    >
      <h2 class="modal-title">New story</h2>
      <input
        class="mz-input"
        bind:value={newTitle}
        placeholder="Story title"
        onkeydown={(e) => {
          if (e.key === 'Enter') void confirmNew();
        }}
      />
      <div class="modal-actions">
        <button class="mz-btn-ghost" onclick={() => (showNew = false)} disabled={creating}
          >Cancel</button
        >
        <button class="mz-btn" onclick={() => confirmNew()} disabled={creating}>
          {creating ? 'Creating…' : 'Create'}
        </button>
      </div>
    </div>
  </div>
{/if}

{#if pendingDelete}
  <div
    class="backdrop"
    role="presentation"
    onclick={() => {
      if (!deleting) pendingDelete = null;
    }}
  >
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div
      class="glass modal"
      role="dialog"
      aria-modal="true"
      aria-label="Delete story"
      tabindex="-1"
      onclick={(e) => e.stopPropagation()}
    >
      <h2 class="modal-title">Delete story?</h2>
      <p class="modal-body">“{pendingDelete.title}” and its pages will be removed.</p>
      <div class="modal-actions">
        <button class="mz-btn-ghost" onclick={() => (pendingDelete = null)} disabled={deleting}>
          Cancel
        </button>
        <button class="mz-btn danger" onclick={() => confirmDelete()} disabled={deleting}>
          {deleting ? 'Deleting…' : 'Delete'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .page {
    position: relative;
    z-index: 1;
    max-width: 960px;
    margin: 0 auto;
    padding: 32px 24px 96px;
  }

  .toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    flex-wrap: wrap;
  }
  .title {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: clamp(26px, 5vw, 40px);
    letter-spacing: 1px;
    margin: 0;
    text-shadow: 0 0 24px rgba(244, 199, 102, 0.25);
  }
  .actions {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    text-decoration: none;
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 18px;
    color: #2a1b05;
    background: radial-gradient(circle at 30% 30%, var(--color-gold), var(--color-amber));
    box-shadow: 0 4px 16px rgba(232, 169, 75, 0.4);
    transition: transform 0.18s ease;
  }
  .avatar:hover {
    transform: translateY(-2px);
  }

  .mz-section-label {
    margin: 18px 0 24px;
  }

  /* State blocks (loading / error / empty) */
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
  .empty-glyph {
    font-size: 56px;
    color: var(--color-gold);
    text-shadow: 0 0 28px rgba(244, 199, 102, 0.45);
    line-height: 1;
  }
  .empty-title {
    font-family: var(--font-display);
    font-size: 24px;
    margin: 0;
  }

  /* Library grid */
  .grid {
    list-style: none;
    padding: 0;
    margin: 0;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 20px;
  }
  .grid :global(.story-card) {
    overflow: hidden;
    display: flex;
    flex-direction: column;
    text-align: left;
  }

  .cover {
    aspect-ratio: 3 / 4;
    background-size: cover;
    background-position: center;
    display: flex;
    align-items: flex-end;
    padding: 14px;
    position: relative;
  }
  .cover::after {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(to top, rgba(11, 16, 38, 0.88), transparent 62%);
  }
  .cover-title {
    position: relative;
    z-index: 1;
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 18px;
    color: var(--color-ink);
    text-shadow: 0 2px 10px rgba(0, 0, 0, 0.75);
  }

  .meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    padding: 12px 14px;
  }
  .meta-count {
    font-size: 13px;
    color: var(--color-ink-muted);
  }
  .meta-actions {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .meta-btn {
    padding: 6px 12px;
    font-size: 13px;
  }
  .meta-btn.icon {
    padding: 6px 8px;
  }

  /* Floating action buttons */
  .fab-stack {
    position: fixed;
    right: 24px;
    bottom: 24px;
    z-index: 5;
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 12px;
  }
  .fab {
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
  .fab:hover {
    transform: translateY(-3px);
    box-shadow: 0 14px 38px rgba(232, 169, 75, 0.55);
  }
  /* Secondary FAB: glass treatment so the two read as distinct affordances. */
  .fab.tell {
    color: var(--color-ink);
    background: rgba(20, 16, 48, 0.72);
    border: 1px solid rgba(244, 199, 102, 0.35);
    backdrop-filter: blur(8px);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
  }
  .fab.tell:hover {
    box-shadow: 0 12px 30px rgba(0, 0, 0, 0.5);
  }

  /* Dialogs */
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
    max-width: 380px;
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
