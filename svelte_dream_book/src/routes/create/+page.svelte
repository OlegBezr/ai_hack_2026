<script lang="ts">
  import { goto } from '$app/navigation';
  import { resolve } from '$app/paths';
  import { toasts } from '$lib/toast.svelte';
  import { canRecord, Recording, transcribeAudio } from '$lib/voice';
  import {
    composeStory,
    generateAudio,
    generateCoverTexture,
    generateIllustration,
    type ComposedStory
  } from '$lib/generation';
  import GlassCard from '$lib/components/GlassCard.svelte';
  import MagicWordmark from '$lib/components/MagicWordmark.svelte';

  type Phase = 'input' | 'composing' | 'generating';

  let phase = $state<Phase>('input');
  let title = $state('');
  let transcript = $state('');
  let error = $state<string | null>(null);

  // Voice capture state.
  let recording = $state<Recording | null>(null);
  let starting = $state(false);
  let transcribing = $state(false);
  const isRecording = $derived(recording !== null);
  const micBusy = $derived(starting || transcribing);

  // Generation progress.
  let statusLine = $state('');
  let mediaDone = $state(0);
  let mediaTotal = $state(0);
  // Resolves when the user taps "Open the book now", letting them skip the wait
  // for slow illustration/narration jobs.
  let openNow: (() => void) | null = null;

  // Upper bounds so a stalled upstream (Anthropic/Midjourney/Deepgram never
  // answering) can never wedge the screen forever — without these a single
  // hung fetch leaves the spinner spinning with no way out.
  const COMPOSE_TIMEOUT_MS = 90_000;
  const MEDIA_TIMEOUT_MS = 120_000;

  const busy = $derived(phase !== 'input');
  const canCreate = $derived(transcript.trim().length >= 10);
  const pct = $derived(mediaTotal === 0 ? 0 : mediaDone / mediaTotal);

  function msg(e: unknown): string {
    return e instanceof Error ? e.message : String(e);
  }

  /** Reject if `p` hasn't settled within `ms` — so nothing waits indefinitely. */
  function withTimeout<T>(p: Promise<T>, ms: number, label: string): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`${label} timed out`)), ms);
      p.then(
        (v) => {
          clearTimeout(timer);
          resolve(v);
        },
        (e) => {
          clearTimeout(timer);
          reject(e);
        }
      );
    });
  }

  // --- Voice capture -------------------------------------------------------

  async function toggleRecording() {
    if (micBusy) return;
    if (recording) {
      await stopAndTranscribe();
    } else {
      await startRecording();
    }
  }

  async function startRecording() {
    error = null;
    starting = true;
    try {
      recording = await Recording.start();
    } catch (e) {
      error =
        msg(e).toLowerCase().includes('denied') || msg(e).includes('NotAllowed')
          ? 'Microphone permission denied.'
          : msg(e);
    } finally {
      starting = false;
    }
  }

  async function stopAndTranscribe() {
    const rec = recording;
    if (!rec) return;
    recording = null;
    transcribing = true;
    try {
      const blob = await rec.stop();
      const text = await transcribeAudio(blob);
      if (text) {
        // Append to whatever's already there so you can narrate in chunks.
        const existing = transcript.trim();
        transcript = existing ? `${existing} ${text}` : text;
      }
    } catch (e) {
      error = msg(e);
    } finally {
      transcribing = false;
    }
  }

  // --- Compose + generate --------------------------------------------------

  /** Run `tasks` with at most `concurrency` in flight (Midjourney rate limits). */
  async function runPooled(tasks: Array<() => Promise<void>>, concurrency: number) {
    let index = 0;
    const worker = async () => {
      while (index < tasks.length) await tasks[index++]();
    };
    await Promise.all(Array.from({ length: Math.min(concurrency, tasks.length || 1) }, worker));
  }

  async function createBook() {
    if (!canCreate) {
      error = 'Tell a bit more of the story first.';
      return;
    }

    error = null;
    phase = 'composing';
    statusLine = 'Weaving your story into pages…';

    let composed: ComposedStory;
    try {
      composed = await withTimeout(
        composeStory(transcript.trim(), { title: title.trim() || undefined }),
        COMPOSE_TIMEOUT_MS,
        'Composing the story'
      );
    } catch (e) {
      error = msg(e);
      phase = 'input';
      return;
    }

    // The book already exists and is readable; now bring it to life. Media is
    // optional — the reader degrades gracefully if some assets fail — so from
    // here on we ALWAYS open the book, even if generation stalls.
    phase = 'generating';
    mediaDone = 0;
    mediaTotal = composed.pages.length * 2 + 1; // audio + illustration per page, + cover
    statusLine = 'Painting illustrations & recording narration…';

    let failures = 0;
    const tick = () => (mediaDone += 1);

    // Narration: Deepgram handles concurrency well — fire all at once.
    const audioJobs = composed.pages.map(async (p) => {
      try {
        await withTimeout(generateAudio(p.id, p.text), MEDIA_TIMEOUT_MS, 'Narration');
      } catch {
        failures += 1;
      } finally {
        tick();
      }
    });

    // Illustrations (+ cover) through a small pool to respect Midjourney limits.
    const imageTasks: Array<() => Promise<void>> = [
      async () => {
        const coverPrompt =
          composed.cover_prompt ||
          `Book cover art for a children's storybook titled "${composed.title}", whimsical illustrated cover`;
        try {
          await withTimeout(
            generateCoverTexture(composed.story_id, coverPrompt),
            MEDIA_TIMEOUT_MS,
            'Cover art'
          );
        } catch {
          failures += 1;
        } finally {
          tick();
        }
      },
      ...composed.pages.map((p) => async () => {
        if (!p.illustration_prompt) {
          tick();
          return;
        }
        try {
          await withTimeout(
            generateIllustration(p.id, p.illustration_prompt),
            MEDIA_TIMEOUT_MS,
            'Illustration'
          );
        } catch {
          failures += 1;
        } finally {
          tick();
        }
      })
    ];

    // Wait for all media — but let the user bail to the finished book early via
    // "Open the book now". Per-job timeouts guarantee this settles regardless.
    const skip = new Promise<void>((r) => (openNow = r));
    await Promise.race([Promise.all([...audioJobs, runPooled(imageTasks, 3)]), skip]);
    openNow = null;

    if (failures > 0) {
      toasts.error(
        `${failures} of ${mediaTotal} assets didn't generate — you can retry them in the editor.`
      );
    }
    await goto(resolve('/read/[id]', { id: composed.story_id }));
  }

  /** Skip the wait and open the (already-created) book immediately. */
  function openBookNow() {
    openNow?.();
  }

  const micLabel = $derived(
    transcribing
      ? 'Transcribing…'
      : starting
        ? 'Starting…'
        : isRecording
          ? 'Tap to stop'
          : 'Tap to speak'
  );
</script>

<div class="page">
  {#if !busy}
    <header class="toolbar">
      <a class="mz-btn-ghost" href={resolve('/')}>← Back</a>
      <h1 class="title">Tell a Story</h1>
      <span class="spacer"></span>
    </header>

    <div class="input">
      <p class="lede">
        Speak your story out loud — beginning to end — then I'll turn it into an illustrated,
        narrated book.
      </p>

      {#if !canRecord()}
        <div class="banner">
          Voice capture isn't available in this browser — but you can still type your story below.
        </div>
      {/if}

      <div class="mic-wrap">
        <button
          class="mic"
          class:recording={isRecording}
          disabled={micBusy}
          onclick={toggleRecording}
          aria-label={micLabel}
        >
          {#if micBusy}
            <span class="mz-spinner"></span>
          {:else}
            <span class="mic-glyph">{isRecording ? '◼' : '🎙'}</span>
          {/if}
        </button>
        <span class="mic-label">{micLabel}</span>
      </div>

      <GlassCard padding="16px">
        <input class="mz-input title-field" bind:value={title} placeholder="Title (optional)" />
        <div class="divider"></div>
        <textarea
          class="transcript"
          bind:value={transcript}
          rows="7"
          placeholder="Your story will appear here as you speak — or just type it."
        ></textarea>
      </GlassCard>

      {#if error}
        <div class="banner error">{error}</div>
      {/if}

      <button class="mz-btn create" disabled={!canCreate} onclick={createBook}>
        ✦ Create the book
      </button>
    </div>
  {:else}
    <div class="progress">
      <MagicWordmark />
      <div class="ring" class:indeterminate={phase === 'composing'}>
        {#if phase === 'composing'}
          <span class="mz-spinner" style="font-size:48px"></span>
        {:else}
          <svg viewBox="0 0 120 120" class="dial" aria-hidden="true">
            <circle class="track" cx="60" cy="60" r="52" />
            <circle
              class="fill"
              cx="60"
              cy="60"
              r="52"
              style:stroke-dasharray={`${pct * 326.7} 326.7`}
            />
          </svg>
        {/if}
      </div>
      <p class="status">{statusLine}</p>
      {#if phase === 'generating'}
        <p class="count">{mediaDone} / {mediaTotal}</p>
        <button class="mz-btn-outline open-now" onclick={openBookNow}>
          Open the book now →
        </button>
        <p class="hint">Illustrations and narration keep generating in the background.</p>
      {/if}
    </div>
  {/if}
</div>

<style>
  .page {
    position: relative;
    z-index: 1;
    max-width: 580px;
    margin: 0 auto;
    padding: 24px 20px 56px;
    min-height: 100vh;
  }

  .toolbar {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 8px;
  }
  .title {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: clamp(22px, 5vw, 32px);
    margin: 0;
    flex: 1;
    text-align: center;
  }
  .spacer {
    width: 64px;
  }

  .input {
    display: flex;
    flex-direction: column;
    gap: 22px;
  }
  .lede {
    text-align: center;
    font-family: var(--font-display);
    font-style: italic;
    font-size: 17px;
    color: var(--color-ink-muted);
    margin: 6px 0 0;
  }

  .mic-wrap {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }
  .mic {
    width: 96px;
    height: 96px;
    border-radius: 50%;
    border: none;
    cursor: pointer;
    display: grid;
    place-items: center;
    color: #2a1b05;
    background: radial-gradient(circle at 30% 30%, var(--color-gold), var(--color-amber));
    box-shadow: 0 0 28px rgba(244, 199, 102, 0.5);
    transition:
      transform 0.18s ease,
      box-shadow 0.18s ease;
  }
  .mic:hover:not(:disabled) {
    transform: translateY(-2px);
  }
  .mic:disabled {
    cursor: default;
    opacity: 0.85;
  }
  .mic.recording {
    background: radial-gradient(circle at 30% 30%, #ff5a5a, #8e1212);
    box-shadow: 0 0 30px rgba(255, 90, 90, 0.55);
    color: #fff;
    animation: pulse 1.4s ease-in-out infinite;
  }
  @keyframes pulse {
    0%,
    100% {
      box-shadow: 0 0 28px rgba(255, 90, 90, 0.45);
    }
    50% {
      box-shadow: 0 0 44px rgba(255, 90, 90, 0.75);
    }
  }
  .mic-glyph {
    font-size: 40px;
    line-height: 1;
  }
  .mic-label {
    font-size: 14px;
    color: var(--color-ink-muted);
  }

  .title-field {
    width: 100%;
    background: transparent;
    border: none;
    font-size: 18px;
  }
  .divider {
    height: 1px;
    background: rgba(255, 255, 255, 0.12);
    margin: 10px 0;
  }
  .transcript {
    width: 100%;
    background: transparent;
    border: none;
    resize: vertical;
    color: var(--color-ink);
    font-family: var(--font-body);
    font-size: 16px;
    line-height: 1.55;
    outline: none;
  }
  .transcript::placeholder {
    color: var(--color-ink-muted);
  }

  .banner {
    padding: 12px 14px;
    border-radius: 12px;
    background: rgba(244, 199, 102, 0.14);
    border: 1px solid rgba(244, 199, 102, 0.3);
    color: var(--color-ink);
    font-size: 14px;
  }
  .banner.error {
    background: rgba(214, 77, 77, 0.16);
    border-color: rgba(214, 77, 77, 0.4);
    color: #ffd7d7;
  }

  .create {
    padding: 15px;
    font-size: 16px;
  }

  /* Progress view */
  .progress {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 26px;
    text-align: center;
    padding-top: 18vh;
  }
  .ring {
    width: 120px;
    height: 120px;
    display: grid;
    place-items: center;
  }
  .dial {
    width: 120px;
    height: 120px;
    transform: rotate(-90deg);
  }
  .dial .track {
    fill: none;
    stroke: rgba(255, 255, 255, 0.12);
    stroke-width: 6;
  }
  .dial .fill {
    fill: none;
    stroke: var(--color-gold);
    stroke-width: 6;
    stroke-linecap: round;
    transition: stroke-dasharray 0.4s ease;
  }
  .status {
    font-family: var(--font-display);
    font-style: italic;
    font-size: 18px;
    margin: 0;
  }
  .count {
    color: var(--color-ink-muted);
    margin: 0;
  }
  .open-now {
    margin-top: 4px;
  }
  .hint {
    color: var(--color-ink-muted);
    font-size: 13px;
    margin: 0;
    max-width: 320px;
  }
</style>
