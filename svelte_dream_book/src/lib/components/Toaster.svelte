<script lang="ts">
  import { toasts } from '$lib/toast.svelte';

  function copy(message: string) {
    void navigator.clipboard?.writeText(message);
  }
</script>

<div class="toaster" role="status" aria-live="polite">
  {#each toasts.items as t (t.id)}
    <div class="toast" class:error={t.isError}>
      <span>{t.message}</span>
      {#if t.isError}
        <button type="button" onclick={() => copy(t.message)}>Copy</button>
      {/if}
    </div>
  {/each}
</div>

<style>
  .toaster {
    position: fixed;
    left: 50%;
    bottom: 24px;
    transform: translateX(-50%);
    z-index: 100;
    display: flex;
    flex-direction: column;
    gap: 8px;
    pointer-events: none;
  }
  .toast {
    pointer-events: auto;
    display: flex;
    align-items: center;
    gap: 14px;
    background: var(--color-night-top);
    color: var(--color-ink);
    border: 1px solid color-mix(in srgb, var(--color-lilac) 30%, transparent);
    border-radius: 14px;
    padding: 12px 16px;
    font-size: 14px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
    max-width: 90vw;
  }
  .toast.error {
    border-color: color-mix(in srgb, var(--color-danger) 60%, transparent);
  }
  .toast button {
    font: inherit;
    font-weight: 700;
    color: var(--color-gold);
    background: none;
    border: none;
    cursor: pointer;
  }
</style>
