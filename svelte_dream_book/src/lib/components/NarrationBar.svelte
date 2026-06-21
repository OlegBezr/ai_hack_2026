<script lang="ts">
  import type { Narration } from '$lib/audio/narration.svelte';

  interface Props {
    narration: Narration;
  }

  let { narration }: Props = $props();

  function fmt(seconds: number): string {
    const s = Number.isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0;
    const m = Math.floor(s / 60);
    const rem = s % 60;
    return `${m}:${rem.toString().padStart(2, '0')}`;
  }
</script>

<div class="bar">
  <button
    class="icon-btn play"
    onclick={() => narration.togglePlay()}
    disabled={!narration.hasAudio}
    title={narration.hasAudio
      ? narration.playing
        ? 'Pause'
        : 'Play'
      : 'No narration on this page'}
    aria-label={narration.playing ? 'Pause narration' : 'Play narration'}
  >
    {#if narration.loading}
      <span class="mz-spinner"></span>
    {:else if narration.playing}
      <span class="glyph">⏸</span>
    {:else}
      <span class="glyph">▶</span>
    {/if}
  </button>

  <div class="scrub">
    {#if !narration.hasAudio}
      <span class="no-audio">No narration on this page</span>
    {:else}
      <input
        class="range"
        type="range"
        min="0"
        max={narration.duration || 0}
        step="0.1"
        bind:value={narration.position}
        oninput={(e) => narration.seek(Number((e.currentTarget as HTMLInputElement).value))}
        aria-label="Seek narration"
      />
      <div class="times">
        <span>{fmt(narration.position)}</span>
        <span>{fmt(narration.duration)}</span>
      </div>
    {/if}
  </div>

  <button
    class="icon-btn"
    onclick={() => narration.replay()}
    disabled={!narration.hasAudio}
    title="Restart"
    aria-label="Restart narration"
  >
    <span class="glyph">↺</span>
  </button>

  <button
    class="icon-btn auto"
    class:on={narration.autoplay}
    onclick={() => narration.setAutoplay(!narration.autoplay)}
    title={narration.autoplay ? 'Auto-narrate on' : 'Auto-narrate off'}
    aria-pressed={narration.autoplay}
    aria-label="Toggle auto-narrate"
  >
    <span class="auto-label">{narration.autoplay ? 'Auto ✓' : 'Auto'}</span>
  </button>
</div>

<style>
  .bar {
    display: flex;
    align-items: center;
    gap: 12px;
    width: min(100%, 520px);
    margin: 0 auto;
    padding: 8px 14px;
    border-radius: 28px;
    background: color-mix(in srgb, var(--color-night-top) 45%, transparent);
    border: 1px solid color-mix(in srgb, var(--color-lilac) 40%, transparent);
    backdrop-filter: blur(12px);
    box-shadow: 0 8px 28px rgba(0, 0, 0, 0.28);
  }

  .icon-btn {
    flex: 0 0 auto;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    border: 1px solid color-mix(in srgb, var(--color-lilac) 30%, transparent);
    background: color-mix(in srgb, var(--color-night-top) 55%, transparent);
    color: var(--color-gold);
    cursor: pointer;
    font-size: 18px;
    transition:
      transform 0.12s ease,
      opacity 0.12s ease;
  }
  .icon-btn:active:not(:disabled) {
    transform: scale(0.94);
  }
  .icon-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
  .play .glyph {
    font-size: 16px;
  }
  .glyph {
    line-height: 1;
  }

  .auto {
    width: auto;
    border-radius: 20px;
    padding: 0 12px;
    font-size: 13px;
    color: var(--color-lilac);
  }
  .auto.on {
    color: var(--color-gold);
    border-color: color-mix(in srgb, var(--color-gold) 55%, transparent);
    background: color-mix(in srgb, var(--color-gold) 14%, transparent);
  }
  .auto-label {
    white-space: nowrap;
    font-weight: 600;
  }

  .scrub {
    flex: 1 1 auto;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .no-audio {
    color: var(--color-ink-muted);
    font-size: 13px;
    text-align: center;
  }
  .times {
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    color: var(--color-ink-muted);
    font-variant-numeric: tabular-nums;
  }

  .range {
    -webkit-appearance: none;
    appearance: none;
    width: 100%;
    height: 4px;
    border-radius: 999px;
    background: color-mix(in srgb, var(--color-gold) 30%, transparent);
    cursor: pointer;
    outline: none;
  }
  .range::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background: var(--color-gold);
    border: none;
    box-shadow: 0 0 8px color-mix(in srgb, var(--color-gold) 55%, transparent);
  }
  .range::-moz-range-thumb {
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background: var(--color-gold);
    border: none;
    box-shadow: 0 0 8px color-mix(in srgb, var(--color-gold) 55%, transparent);
  }
  .range::-moz-range-track {
    height: 4px;
    border-radius: 999px;
    background: color-mix(in srgb, var(--color-gold) 30%, transparent);
  }
</style>
