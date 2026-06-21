<script lang="ts">
  import { resolve } from '$app/paths';
  import { goto } from '$app/navigation';
  import { auth } from '$lib/auth.svelte';
  import { fetchMyProfile, updateName } from '$lib/profile';
  import { toasts } from '$lib/toast.svelte';
  import GlassCard from '$lib/components/GlassCard.svelte';

  let loading = $state(true);
  let error = $state<string | null>(null);
  let saving = $state(false);
  let name = $state('');

  const email = $derived(auth.user?.email ?? '');

  const initial = $derived.by(() => {
    const source = name.trim().length > 0 ? name.trim() : email;
    return source.length > 0 ? source[0].toUpperCase() : '?';
  });

  async function load() {
    loading = true;
    error = null;
    try {
      const profile = await fetchMyProfile();
      name = profile?.name ?? '';
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      loading = false;
    }
  }

  async function save() {
    if (saving) return;
    saving = true;
    try {
      await updateName(name.trim());
      toasts.show('Profile saved');
    } catch (e: unknown) {
      toasts.error('Failed to save: ' + (e instanceof Error ? e.message : String(e)));
    } finally {
      saving = false;
    }
  }

  function handleSubmit(e: SubmitEvent) {
    e.preventDefault();
    void save();
  }

  $effect(() => {
    void load();
  });
</script>

<div class="page">
  <div class="content">
    <div class="topbar">
      <button class="mz-btn-ghost back" type="button" onclick={() => void goto(resolve('/'))}>
        ‹ Library
      </button>
      <h1 class="title">Profile</h1>
    </div>

    {#if loading}
      <div class="center">
        <span class="mz-spinner"></span>
      </div>
    {:else if error}
      <div class="center error-block">
        <div class="error-icon">⚠</div>
        <p class="error-text">{error}</p>
        <button class="mz-btn" type="button" onclick={() => void load()}>Retry</button>
      </div>
    {:else}
      <div class="avatar-header">
        <div class="avatar">{initial}</div>
      </div>

      <section class="section">
        <div class="mz-section-label">Account</div>
        <GlassCard padding="14px 16px">
          <div class="account-row">
            <div class="glyph">✉</div>
            <div class="account-text">
              <div class="account-label">Email</div>
              <div class="account-value">{email}</div>
            </div>
            <div class="lock" title="Can't be changed">🔒</div>
          </div>
        </GlassCard>
      </section>

      <section class="section">
        <div class="mz-section-label">Display name</div>
        <form onsubmit={handleSubmit}>
          <input
            class="mz-input"
            type="text"
            placeholder="Your display name"
            autocapitalize="words"
            bind:value={name}
          />
          <p class="helper">How your name appears in the app.</p>
          <button class="mz-btn" type="submit" disabled={saving}>
            {#if saving}
              <span class="mz-spinner"></span>
              Saving…
            {:else}
              Save
            {/if}
          </button>
        </form>
      </section>
    {/if}
  </div>
</div>

<style>
  .page {
    position: relative;
    z-index: 1;
    min-height: 100vh;
    display: flex;
    justify-content: center;
    padding: 24px;
  }

  .content {
    display: flex;
    flex-direction: column;
    gap: 24px;
    width: 100%;
    max-width: 480px;
  }

  .topbar {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .back {
    align-self: flex-start;
    padding-left: 0;
    padding-right: 0;
  }

  .title {
    margin: 0;
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 1.75rem;
    letter-spacing: 1px;
    color: var(--color-ink);
  }

  .center {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    padding: 48px 0;
  }

  .error-block {
    text-align: center;
  }

  .error-icon {
    font-size: 2rem;
    color: var(--color-danger);
  }

  .error-text {
    margin: 0;
    font-family: var(--font-body);
    color: var(--color-danger);
  }

  .avatar-header {
    display: flex;
    justify-content: center;
    padding: 8px 0;
  }

  .avatar {
    width: 88px;
    height: 88px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: radial-gradient(circle at 50% 35%, var(--color-gold), var(--color-amber));
    box-shadow: 0 12px 36px rgba(244, 199, 102, 0.4);
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 40px;
    color: #2a1b05;
  }

  .section {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .account-row {
    display: flex;
    align-items: center;
    gap: 14px;
  }

  .glyph {
    font-size: 1.25rem;
    color: var(--color-gold);
    flex-shrink: 0;
  }

  .account-text {
    flex: 1;
    min-width: 0;
  }

  .account-label {
    font-family: var(--font-body);
    font-size: 0.78rem;
    font-weight: 700;
    color: var(--color-ink);
  }

  .account-value {
    font-family: var(--font-body);
    font-size: 0.92rem;
    color: var(--color-ink-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .lock {
    font-size: 0.95rem;
    flex-shrink: 0;
    cursor: default;
  }

  form {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .helper {
    margin: 0 0 4px;
    font-family: var(--font-body);
    font-size: 0.82rem;
    color: var(--color-ink-muted);
  }
</style>
