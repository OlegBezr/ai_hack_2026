<script lang="ts">
  interface Props {
    text?: string;
    size?: number;
    icon?: boolean;
  }
  let { text = 'Dream Book', size = 40, icon = true }: Props = $props();
</script>

<div class="wordmark" style:font-size="{size}px">
  {#if icon}
    <span class="spark" style:font-size="{size * 0.9}px" aria-hidden="true">✦</span>
  {/if}
  <span class="word">{text}</span>
</div>

<style>
  .wordmark {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.3em;
    font-family: var(--font-display);
    font-weight: 700;
    letter-spacing: 2px;
    color: var(--color-ink);
    text-shadow:
      0 0 24px rgba(244, 199, 102, 0.55),
      0 2px 2px rgba(0, 0, 0, 0.67);
  }
  .spark {
    color: var(--color-gold);
    filter: drop-shadow(0 0 18px rgba(244, 199, 102, 0.45));
  }
</style>
