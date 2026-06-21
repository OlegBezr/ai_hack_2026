<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { PageFlip } from '$lib/vendor/stpageflip/PageFlip';
  import { SizeType } from '$lib/vendor/stpageflip/Settings';
  import { proseStyle, type StoryStyle, type PageRow } from '$lib/types';

  interface Props {
    title: string;
    coverTexture?: string | null;
    pages: PageRow[];
    style: StoryStyle;
    /** Leaf index to open on (0 = cover). Diagnostic/testing aid. */
    startPage?: number;
    /** Called once the flip engine is ready; hands back simple controls. */
    oninit?: (api: { next: () => void; prev: () => void; pageCount: number }) => void;
    /** Fired on every turn with the current left-leaf index. */
    onflip?: (leftLeaf: number) => void;
  }

  let { title, coverTexture, pages, style, startPage = 0, oninit, onflip }: Props = $props();

  let bookEl: HTMLDivElement;
  let pageFlip: PageFlip | undefined;

  const textStyle = $derived(proseStyle(style));
  const leafBg = $derived(style.backgroundColor ?? '#FFF8E7');

  onMount(() => {
    pageFlip = new PageFlip(bookEl, {
      width: 400,
      height: 560, // ~ portrait page aspect
      size: SizeType.STRETCH,
      minWidth: 140, // keep low so the spread can shrink to fit short stages
      maxWidth: 500, // two pages → up to ~1000 wide (matches the stage)
      minHeight: 190,
      maxHeight: 760,
      showCover: true,
      drawShadow: true,
      flippingTime: 700,
      usePortrait: false, // always a two-page spread: text left, illustration right
      maxShadowOpacity: 0.5,
      mobileScrollSupport: false,
      // No hover-fold — flipping only begins on press/drag (or touch).
      showPageCorners: false,
      startPage
    });

    pageFlip.loadFromHTML(bookEl.querySelectorAll<HTMLElement>('.leaf'));

    pageFlip.on('flip', (e) => onflip?.(e.data as number));

    oninit?.({
      next: () => pageFlip?.flipNext(),
      prev: () => pageFlip?.flipPrev(),
      pageCount: pageFlip.getPageCount()
    });
  });

  onDestroy(() => {
    pageFlip?.destroy();
    pageFlip = undefined;
  });
</script>

<div class="book" bind:this={bookEl}>
  <!-- Front cover (hard): texture + scrim + glowing engraved title -->
  <div class="leaf leaf--cover leaf--cover-front" data-density="hard">
    {#if coverTexture}
      <img class="cover-art" src={coverTexture} alt="" />
    {/if}
    <div class="cover-scrim"></div>
    <h1 class="cover-title">{title}</h1>
  </div>

  <!-- Each story page becomes a spread: text on the left, illustration on the right -->
  {#each pages as p (p.id)}
    <div class="leaf leaf--text" style:background-color={leafBg}>
      <div class="prose" style={textStyle}>{p.text ?? ''}</div>
    </div>
    <div class="leaf leaf--art" style:background-color={leafBg}>
      {#if p.illustration_url}
        <img class="art-img" src={p.illustration_url} alt="" />
      {:else}
        <div class="illustration-placeholder">✦</div>
      {/if}
    </div>
  {/each}

  <!-- Closing spread: blank left page, "The End" centered on the right -->
  <div class="leaf leaf--blank" style:background-color={leafBg}></div>
  <div class="leaf leaf--end" style:background-color={leafBg}>
    <p class="end-text">The End</p>
  </div>

  <!-- Back cover (hard, shown alone so the book can close): same art, no title -->
  <div class="leaf leaf--cover" data-density="hard">
    {#if coverTexture}
      <img class="cover-art" src={coverTexture} alt="" />
    {/if}
    <div class="cover-scrim"></div>
  </div>
</div>

<style>
  .book {
    margin: 0 auto;
    touch-action: manipulation;
    user-select: none;
  }

  .leaf {
    box-sizing: border-box;
    height: 100%;
    overflow: hidden;
    background: #fdfaf3;
    box-shadow: inset 0 0 60px rgba(0, 0, 0, 0.04);
  }

  /* Text page (left) */
  .leaf--text {
    display: block;
  }
  .prose {
    height: 100%;
    padding: 44px 38px;
    overflow-y: auto;
    white-space: pre-wrap;
  }

  /* Illustration page (right) */
  .leaf--art {
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .art-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  .illustration-placeholder {
    font-size: 44px;
    color: #b9ad84;
  }

  /* Closing pages */
  .leaf--blank {
    display: block;
  }
  .leaf--end {
    display: grid;
    place-items: center;
    width: 100%;
    padding: 24px;
  }
  .end-text {
    margin: 0;
    text-align: center;
    font-family: 'Cinzel', serif;
    font-weight: 600;
    font-size: clamp(22px, 4vw, 34px);
    letter-spacing: 3px;
    /* letter-spacing adds trailing space after the last glyph; pull it back so
       the text is optically centered. */
    text-indent: 3px;
    color: #6b4a2b;
    text-shadow: 0 1px 0 rgba(255, 255, 255, 0.5);
  }

  /* Cover / back-cover leaves */
  .leaf--cover {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(160deg, #1a1340, #2c1b4d);
  }
  /* Front cover: nudge the title down for a bit more top offset */
  .leaf--cover-front {
    align-items: flex-start;
    justify-content: center;
    padding-top: 22%;
  }
  .cover-art {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  .cover-scrim {
    position: absolute;
    inset: 0;
    background: radial-gradient(ellipse at center, rgba(11, 16, 38, 0.25), rgba(11, 16, 38, 0.85));
  }
  .cover-title {
    position: relative;
    margin: 0;
    padding: 0 28px;
    text-align: center;
    font-family: 'Cinzel', serif;
    font-weight: 700;
    font-size: clamp(24px, 5vw, 40px);
    letter-spacing: 1.5px;
    color: #f3ecff;
    text-shadow:
      0 0 18px rgba(244, 199, 102, 0.55),
      0 2px 6px rgba(0, 0, 0, 0.6);
  }
</style>
