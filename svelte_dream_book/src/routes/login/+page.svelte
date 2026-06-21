<script lang="ts">
  import { auth } from '$lib/auth.svelte';
  import MagicWordmark from '$lib/components/MagicWordmark.svelte';

  let email = $state('');
  let code = $state('');
  let codeSent = $state(false);
  let loading = $state(false);
  let error = $state<string | null>(null);

  async function sendCode() {
    const trimmed = email.trim();
    if (trimmed.length === 0 || !trimmed.includes('@')) {
      error = 'Enter a valid email address.';
      return;
    }
    error = null;
    loading = true;
    try {
      await auth.signInWithOtp(trimmed);
      codeSent = true;
    } catch (e: unknown) {
      error = 'Could not send code: ' + (e instanceof Error ? e.message : String(e));
    } finally {
      loading = false;
    }
  }

  async function verify() {
    const trimmed = code.trim();
    if (trimmed.length < 6) {
      error = 'Enter the 6-digit code.';
      return;
    }
    error = null;
    loading = true;
    try {
      // On success the global session updates and the root layout redirects to '/'.
      await auth.verifyOtp(email.trim(), trimmed);
    } catch (e: unknown) {
      error = 'Invalid or expired code: ' + (e instanceof Error ? e.message : String(e));
    } finally {
      loading = false;
    }
  }

  function changeEmail() {
    codeSent = false;
    code = '';
    error = null;
  }

  function handleSubmit(e: SubmitEvent) {
    e.preventDefault();
    if (codeSent) {
      void verify();
    } else {
      void sendCode();
    }
  }
</script>

<div class="page">
  <div class="content">
    <div class="brand">
      <MagicWordmark />
    </div>

    <form class="glass card" onsubmit={handleSubmit}>
      {#if codeSent}
        <h1 class="heading">Check your owl post</h1>
        <p class="subtext">Enter the 6-digit code we emailed you.</p>
      {:else}
        <h1 class="heading">Enter the gate</h1>
        <p class="subtext">Sign in with a one-time email code.</p>
      {/if}

      <input
        class="mz-input"
        type="email"
        placeholder="Email"
        autocomplete="username"
        bind:value={email}
        disabled={codeSent}
      />

      {#if codeSent}
        <!-- svelte-ignore a11y_autofocus -->
        <input
          class="mz-input"
          type="text"
          inputmode="numeric"
          maxlength="6"
          placeholder="6-digit code"
          autocomplete="one-time-code"
          autofocus
          bind:value={code}
        />
      {/if}

      {#if error}
        <p class="error">{error}</p>
      {/if}

      <button class="mz-btn" type="submit" disabled={loading}>
        {#if loading}
          <span class="mz-spinner"></span>
        {:else if codeSent}
          Verify
        {:else}
          Send code
        {/if}
      </button>

      {#if codeSent}
        <div class="actions">
          <button class="mz-btn-ghost" type="button" onclick={changeEmail} disabled={loading}>
            Change email
          </button>
          <button
            class="mz-btn-ghost"
            type="button"
            onclick={() => void sendCode()}
            disabled={loading}
          >
            Resend code
          </button>
        </div>
      {/if}
    </form>
  </div>
</div>

<style>
  .page {
    position: relative;
    z-index: 1;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
  }

  .content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 28px;
    width: 100%;
    max-width: 380px;
  }

  .brand {
    display: flex;
    justify-content: center;
  }

  .card {
    display: flex;
    flex-direction: column;
    gap: 16px;
    width: 100%;
    padding: 32px 28px;
  }

  .heading {
    margin: 0;
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 1.5rem;
    letter-spacing: 1px;
    color: var(--color-ink);
    text-align: center;
  }

  .subtext {
    margin: 0 0 4px;
    font-family: var(--font-body);
    font-size: 0.95rem;
    color: var(--color-ink-muted);
    text-align: center;
  }

  .actions {
    display: flex;
    justify-content: space-between;
    gap: 8px;
  }

  .error {
    margin: 0;
    font-family: var(--font-body);
    font-size: 0.88rem;
    color: var(--color-danger);
    text-align: center;
  }
</style>
