<script lang="ts">
  import { COLOR_SWATCHES, hexFromRgb, rgbFromHex } from '$lib/types';

  let {
    label,
    selected,
    onPick
  }: {
    label: string;
    selected: string | null;
    onPick: (hex: string | null) => void;
  } = $props();

  let showDialog = $state(false);
  let r = $state(136);
  let g = $state(136);
  let b = $state(136);

  const customHex = $derived(hexFromRgb(r, g, b));

  // True when the current selection is a custom color (not one of the presets).
  const isCustom = $derived(
    selected !== null &&
      !COLOR_SWATCHES.some((s) => s !== null && s.toUpperCase() === selected.toUpperCase())
  );

  /** Pick readable text color for a preview chip against an arbitrary bg. */
  function contrastFor(hex: string): string {
    const { r: rr, g: gg, b: bb } = rgbFromHex(hex);
    const luminance = (0.299 * rr + 0.587 * gg + 0.114 * bb) / 255;
    return luminance > 0.55 ? '#1a1340' : '#fff8e7';
  }

  function openCustom() {
    const seed = rgbFromHex(selected ?? '#888888');
    r = seed.r;
    g = seed.g;
    b = seed.b;
    showDialog = true;
  }

  function confirmCustom() {
    onPick(hexFromRgb(r, g, b));
    showDialog = false;
  }

  function isSelectedSwatch(value: string | null): boolean {
    if (value === null) return selected === null;
    return selected !== null && value.toUpperCase() === selected.toUpperCase();
  }
</script>

<div class="picker">
  <span class="picker-label">{label}</span>
  <div class="swatches">
    {#each COLOR_SWATCHES as value (value ?? 'default')}
      <button
        type="button"
        class="swatch"
        class:selected={isSelectedSwatch(value)}
        class:is-default={value === null}
        style:background={value ?? 'transparent'}
        aria-label={value === null ? 'Use default color' : value}
        onclick={() => onPick(value)}
      >
        {#if value === null}<span class="slash">∅</span>{/if}
      </button>
    {/each}
    <button
      type="button"
      class="swatch custom"
      class:selected={isCustom}
      style:background={isCustom ? selected : undefined}
      aria-label="Custom color"
      onclick={openCustom}
    >
      {#if !isCustom}<span class="plus">+</span>{/if}
    </button>
  </div>
</div>

{#if showDialog}
  <div class="backdrop" role="presentation" onclick={() => (showDialog = false)}>
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div
      class="glass modal"
      role="dialog"
      aria-modal="true"
      aria-label="Custom color"
      tabindex="-1"
      onclick={(e) => e.stopPropagation()}
    >
      <h2 class="modal-title">Custom color</h2>
      <div class="preview" style:background={customHex} style:color={contrastFor(customHex)}>
        {customHex}
      </div>
      <label class="channel">
        <span>R</span>
        <input type="range" min="0" max="255" step="1" bind:value={r} />
        <span class="val">{r}</span>
      </label>
      <label class="channel">
        <span>G</span>
        <input type="range" min="0" max="255" step="1" bind:value={g} />
        <span class="val">{g}</span>
      </label>
      <label class="channel">
        <span>B</span>
        <input type="range" min="0" max="255" step="1" bind:value={b} />
        <span class="val">{b}</span>
      </label>
      <div class="modal-actions">
        <button class="mz-btn-ghost" onclick={() => (showDialog = false)}>Cancel</button>
        <button class="mz-btn" onclick={confirmCustom}>Select</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .picker {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .picker-label {
    font-size: 13px;
    color: var(--color-ink-muted);
  }
  .swatches {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }
  .swatch {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    border: 1px solid color-mix(in srgb, var(--color-ink) 22%, transparent);
    cursor: pointer;
    padding: 0;
    display: grid;
    place-items: center;
    transition: transform 0.12s ease;
  }
  .swatch:hover {
    transform: scale(1.08);
  }
  .swatch.selected {
    border: 2.5px solid var(--color-gold);
    box-shadow: 0 0 10px rgba(244, 199, 102, 0.5);
  }
  .swatch.is-default {
    background: color-mix(in srgb, var(--color-surface) 70%, transparent);
  }
  .slash {
    font-size: 14px;
    color: var(--color-ink-muted);
    line-height: 1;
  }
  .swatch.custom {
    background: conic-gradient(from 0deg, #ff004c, #ffb800, #38ff7a, #00d4ff, #6a5cff, #ff004c);
  }
  .plus {
    font-size: 16px;
    font-weight: 700;
    color: #fff;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.6);
    line-height: 1;
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
    max-width: 340px;
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
  .preview {
    border-radius: var(--radius-control);
    padding: 18px;
    text-align: center;
    font-family: var(--font-display);
    font-weight: 600;
    letter-spacing: 1px;
  }
  .channel {
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 14px;
    color: var(--color-ink);
  }
  .channel > span:first-child {
    width: 14px;
    font-weight: 600;
    color: var(--color-ink-muted);
  }
  .channel input {
    flex: 1;
    accent-color: var(--color-gold);
  }
  .channel .val {
    width: 32px;
    text-align: right;
    font-variant-numeric: tabular-nums;
    color: var(--color-ink-muted);
  }
  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
  }
</style>
