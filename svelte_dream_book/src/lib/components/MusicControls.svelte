<script lang="ts">
  import { backgroundMusic, TRACKS } from '$lib/audio/background-music.svelte';

  let open = $state(false);
  let root = $state<HTMLDivElement>();

  function onWindowClick(e: MouseEvent) {
    if (open && root && !root.contains(e.target as Node)) open = false;
  }

  function onWindowKey(e: KeyboardEvent) {
    if (open && e.key === 'Escape') open = false;
  }
</script>

<svelte:window onclick={onWindowClick} onkeydown={onWindowKey} />

<div class="music" bind:this={root}>
  <div class="bar glass">
    <button
      type="button"
      class="icon"
      onclick={() => backgroundMusic.toggleMute()}
      title={backgroundMusic.muted ? 'Unmute music' : 'Mute music'}
      aria-label={backgroundMusic.muted ? 'Unmute music' : 'Mute music'}
    >
      {backgroundMusic.muted ? '🔇' : '🔊'}
    </button>
    <button
      type="button"
      class="icon gear"
      onclick={() => (open = !open)}
      title="Music settings"
      aria-label="Music settings"
    >
      <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <path
          d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"
        />
        <circle cx="12" cy="12" r="3" />
      </svg>
    </button>
  </div>

  {#if open}
    <div class="sheet glass">
      <p class="sheet-title">Background music</p>
      {#each TRACKS as track, i (track.asset)}
        <button
          type="button"
          class="track"
          class:selected={i === backgroundMusic.trackIndex}
          onclick={() => {
            backgroundMusic.selectTrack(i);
            open = false;
          }}
        >
          <span class="track-icon">{i === backgroundMusic.trackIndex ? '▮▮▮' : '♪'}</span>
          <span class="track-label">{track.label}</span>
          {#if i === backgroundMusic.trackIndex}<span class="check">✓</span>{/if}
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .music {
    position: fixed;
    left: 16px;
    bottom: 16px;
    z-index: 50;
  }
  .bar {
    display: inline-flex;
    gap: 4px;
    padding: 4px 6px;
    border-radius: 24px;
    background-color: rgba(0, 0, 0, 0.28);
  }
  .icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: none;
    border: none;
    color: var(--color-gold);
    font-size: 18px;
    line-height: 1;
    width: 38px;
    height: 38px;
    padding: 0;
    border-radius: 50%;
    cursor: pointer;
  }
  .icon:hover {
    background: rgba(255, 255, 255, 0.08);
  }
  /* An inline SVG (instead of the ⚙ glyph) so the gear sizes precisely and
     centers perfectly — the unicode glyph has asymmetric metrics. */
  .gear svg {
    width: 22px;
    height: 22px;
    display: block;
  }
  .sheet {
    position: absolute;
    bottom: 56px;
    left: 0;
    min-width: 220px;
    padding: 8px;
    background-color: color-mix(in srgb, var(--color-night-mid) 92%, transparent);
  }
  .sheet-title {
    font-family: var(--font-display);
    font-size: 16px;
    margin: 8px 12px 10px;
  }
  .track {
    display: flex;
    align-items: center;
    gap: 12px;
    width: 100%;
    background: none;
    border: none;
    color: var(--color-ink);
    padding: 10px 12px;
    border-radius: 10px;
    cursor: pointer;
    font: inherit;
    text-align: left;
  }
  .track:hover {
    background: rgba(255, 255, 255, 0.06);
  }
  .track.selected {
    color: var(--color-gold);
    font-weight: 700;
  }
  .track-icon {
    color: var(--color-lilac);
    font-size: 12px;
    width: 28px;
  }
  .track.selected .track-icon {
    color: var(--color-gold);
  }
  .track-label {
    flex: 1;
  }
  .check {
    color: var(--color-gold);
  }
</style>
