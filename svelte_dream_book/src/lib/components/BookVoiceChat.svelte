<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import type { StoryWithPages } from '$lib/types';
  import { VoiceAgentController, type VoiceAgentPhase } from '$lib/voice/voice-agent.svelte';
  import { buildBookSystemPrompt, buildGreeting } from '$lib/voice/book-prompt';

  let { story, onClose }: { story: StoryWithPages; onClose: () => void } = $props();

  const agent = new VoiceAgentController();

  // Auto-scroll the transcript as new turns arrive.
  let scroller = $state<HTMLDivElement | null>(null);
  $effect(() => {
    // Touch the length so the effect re-runs on every appended turn.
    agent.transcript.length;
    if (scroller) scroller.scrollTo({ top: scroller.scrollHeight, behavior: 'smooth' });
  });

  onMount(() => {
    void agent.connect(buildBookSystemPrompt(story), buildGreeting(story));
  });

  onDestroy(() => {
    void agent.disconnect();
  });

  function close(): void {
    void agent.disconnect();
    onClose();
  }

  // Per-phase orb styling, mirroring the Flutter _StatusOrb.
  const ORB: Record<VoiceAgentPhase, { color: string; icon: string; label: string }> = {
    connecting: { color: 'var(--color-lilac)', icon: '⏳', label: 'Connecting…' },
    listening: { color: 'var(--color-gold)', icon: '🎙️', label: 'Listening — go ahead' },
    thinking: { color: 'var(--color-lilac)', icon: '✨', label: 'Thinking…' },
    speaking: { color: 'var(--color-gold)', icon: '🔊', label: 'Speaking…' },
    error: { color: 'var(--color-danger)', icon: '⚠️', label: 'Something went wrong' },
    idle: { color: 'var(--color-ink-muted)', icon: '🔇', label: 'Chat ended' }
  };

  const orb = $derived(ORB[agent.phase]);
  const active = $derived(
    agent.phase === 'listening' || agent.phase === 'speaking' || agent.phase === 'thinking'
  );
</script>

<svelte:window
  onkeydown={(e) => {
    if (e.key === 'Escape') close();
  }}
/>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="backdrop" role="presentation" onclick={close}>
  <div
    class="sheet glass"
    role="dialog"
    aria-modal="true"
    aria-label="Talk about this book"
    tabindex="-1"
    onclick={(e) => e.stopPropagation()}
  >
    <header class="head">
      <span class="head-icon" aria-hidden="true">🎚️</span>
      <div class="head-text">
        <h2>Talk about this book</h2>
        <p class="title">{story.title}</p>
      </div>
      <button class="close" type="button" aria-label="End chat" onclick={close}>✕</button>
    </header>

    {#if agent.error}
      <div class="banner" role="alert">
        <span aria-hidden="true">⚠️</span>
        <span>{agent.error}</span>
      </div>
    {/if}

    <div class="orb-wrap">
      <div class="orb" class:active style:--orb={orb.color}>
        {#if agent.phase === 'connecting'}
          <span class="mz-spinner"></span>
        {:else}
          <span class="orb-icon" aria-hidden="true">{orb.icon}</span>
        {/if}
      </div>
      <p class="orb-label">{orb.label}</p>
    </div>

    <div class="transcript" bind:this={scroller}>
      {#if agent.transcript.length === 0}
        <p class="empty">
          {agent.phase === 'connecting'
            ? 'Warming up the storyteller…'
            : 'Say hello, then ask anything about the story.'}
        </p>
      {:else}
        {#each agent.transcript as turn, i (i)}
          <div class="bubble" class:user={turn.role === 'user'}>{turn.text}</div>
        {/each}
      {/if}
    </div>
  </div>
</div>

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    z-index: 70;
    background: rgba(6, 9, 24, 0.82);
    backdrop-filter: blur(6px);
    display: flex;
    align-items: flex-end;
    justify-content: center;
    padding: 24px 16px 0;
  }
  .sheet {
    width: 100%;
    max-width: 560px;
    height: min(82dvh, 720px);
    display: flex;
    flex-direction: column;
    border-radius: var(--radius-dialog) var(--radius-dialog) 0 0;
    border-bottom: none;
    overflow: hidden;
  }
  .head {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 16px 12px 12px 20px;
  }
  .head-icon {
    font-size: 20px;
  }
  .head-text {
    flex: 1 1 auto;
    min-width: 0;
  }
  .head-text h2 {
    margin: 0;
    font-family: var(--font-display);
    font-size: 20px;
    font-weight: 600;
    color: var(--color-ink);
  }
  .head-text .title {
    margin: 0;
    font-size: 13px;
    color: var(--color-ink-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .close {
    flex: 0 0 auto;
    width: 36px;
    height: 36px;
    border-radius: 50%;
    font-size: 16px;
    color: var(--color-ink);
    border: 1px solid color-mix(in srgb, var(--color-lilac) 30%, transparent);
    background: color-mix(in srgb, var(--color-night-top) 50%, transparent);
    cursor: pointer;
  }
  .banner {
    display: flex;
    align-items: center;
    gap: 10px;
    margin: 4px 16px;
    padding: 12px;
    font-size: 13px;
    color: var(--color-ink);
    border-radius: 12px;
    background: color-mix(in srgb, var(--color-danger) 16%, transparent);
    border: 1px solid color-mix(in srgb, var(--color-danger) 50%, transparent);
  }
  .orb-wrap {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 8px 0 12px;
  }
  .orb {
    width: 64px;
    height: 64px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    background: color-mix(in srgb, var(--orb) 16%, transparent);
    border: 1px solid color-mix(in srgb, var(--orb) 60%, transparent);
    box-shadow: 0 0 24px color-mix(in srgb, var(--orb) 20%, transparent);
    transform: scale(0.9);
    transition:
      transform 0.7s ease-in-out,
      box-shadow 0.7s ease-in-out;
  }
  .orb.active {
    transform: scale(1);
    box-shadow: 0 0 28px color-mix(in srgb, var(--orb) 45%, transparent);
    animation: pulse 1.6s ease-in-out infinite;
  }
  @keyframes pulse {
    0%,
    100% {
      transform: scale(0.94);
    }
    50% {
      transform: scale(1.04);
    }
  }
  .orb-icon {
    font-size: 26px;
    line-height: 1;
  }
  .orb-label {
    margin: 0;
    font-size: 13px;
    color: var(--color-ink-muted);
  }
  .transcript {
    flex: 1 1 auto;
    min-height: 0;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 8px 16px 24px;
  }
  .empty {
    margin: auto;
    max-width: 280px;
    text-align: center;
    font-size: 15px;
    color: var(--color-ink-muted);
  }
  .bubble {
    align-self: flex-start;
    max-width: 78%;
    padding: 10px 14px;
    font-size: 15px;
    line-height: 1.4;
    color: var(--color-ink);
    border-radius: 16px 16px 16px 4px;
    background: color-mix(in srgb, var(--color-lilac) 16%, transparent);
    border: 1px solid color-mix(in srgb, var(--color-lilac) 40%, transparent);
  }
  .bubble.user {
    align-self: flex-end;
    border-radius: 16px 16px 4px 16px;
    background: color-mix(in srgb, var(--color-gold) 18%, transparent);
    border-color: color-mix(in srgb, var(--color-gold) 40%, transparent);
  }
</style>
