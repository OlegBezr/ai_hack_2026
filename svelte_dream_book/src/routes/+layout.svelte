<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { resolve } from '$app/paths';
  import { auth } from '$lib/auth.svelte';
  import MagicalBackground from '$lib/components/MagicalBackground.svelte';
  import MusicControls from '$lib/components/MusicControls.svelte';
  import Toaster from '$lib/components/Toaster.svelte';

  let { children } = $props();

  onMount(() => auth.init());

  // Route guard, mirroring the Flutter go_router redirect: unauthenticated users
  // hitting a protected route bounce to /login; signed-in users at /login bounce
  // home. Runs once the initial session check resolves.
  const isLogin = $derived(page.url.pathname === '/login');
  const onReader = $derived(page.url.pathname.startsWith('/read/'));

  $effect(() => {
    if (!auth.ready) return;
    if (!auth.signedIn && !isLogin) {
      void goto(resolve('/login'));
    } else if (auth.signedIn && isLogin) {
      void goto(resolve('/'));
    }
  });
</script>

<MagicalBackground />

{#if auth.ready}
  {@render children()}
{:else}
  <div class="boot"><span class="mz-spinner" style="font-size:28px"></span></div>
{/if}

{#if auth.signedIn && !onReader}
  <MusicControls />
{/if}

<Toaster />

<style>
  .boot {
    position: relative;
    z-index: 1;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
  }
</style>
