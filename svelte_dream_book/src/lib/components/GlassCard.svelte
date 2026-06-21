<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    children: Snippet;
    padding?: string;
    class?: string;
    onclick?: () => void;
    href?: string;
  }

  let { children, padding = '16px', class: klass = '', onclick, href }: Props = $props();
</script>

{#if href}
  <!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- `href` is a passthrough prop; callers resolve() it before passing it in. -->
  <a {href} class="glass card {klass}" style:padding {onclick}>
    {@render children()}
  </a>
{:else if onclick}
  <button type="button" class="glass card {klass}" style:padding {onclick}>
    {@render children()}
  </button>
{:else}
  <div class="glass card {klass}" style:padding>
    {@render children()}
  </div>
{/if}

<style>
  .card {
    display: block;
    color: var(--color-ink);
    text-decoration: none;
    text-align: inherit;
    font: inherit;
    width: 100%;
    box-sizing: border-box;
  }
  a.card,
  button.card {
    cursor: pointer;
    transition:
      transform 0.18s ease,
      box-shadow 0.18s ease;
  }
  a.card:hover,
  button.card:hover {
    transform: translateY(-3px);
    box-shadow: 0 14px 40px rgba(0, 0, 0, 0.4);
  }
</style>
