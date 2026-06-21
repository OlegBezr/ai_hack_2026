<script lang="ts">
  let {
    src,
    alt = '',
    onClose
  }: { src: string; alt?: string; onClose: () => void } = $props();
</script>

<svelte:window
  onkeydown={(e) => {
    if (e.key === 'Escape') onClose();
  }}
/>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="backdrop" role="presentation" onclick={onClose}>
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <img class="full" {src} {alt} onclick={(e) => e.stopPropagation()} />
  <button class="close" type="button" aria-label="Close" onclick={onClose}>✕</button>
</div>

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    z-index: 60;
    background: rgba(6, 9, 24, 0.82);
    backdrop-filter: blur(6px);
    display: grid;
    place-items: center;
    padding: 32px;
    cursor: zoom-out;
  }
  .full {
    max-width: 100%;
    max-height: 100%;
    border-radius: var(--radius-card);
    box-shadow: 0 24px 70px rgba(0, 0, 0, 0.55);
    cursor: default;
  }
  .close {
    position: fixed;
    top: 18px;
    right: 18px;
    width: 44px;
    height: 44px;
    border-radius: 50%;
    font-size: 18px;
    color: var(--color-ink);
    border: 1px solid color-mix(in srgb, var(--color-lilac) 30%, transparent);
    background: color-mix(in srgb, var(--color-night-top) 60%, transparent);
    cursor: pointer;
  }
  .close:hover {
    background: color-mix(in srgb, var(--color-night-top) 80%, transparent);
  }
</style>
