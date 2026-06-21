<script lang="ts">
  import { onMount } from 'svelte';

  // Twinkling starfield + glow orbs, ported from the Flutter MagicalBackground
  // painter: 70 stars, sinusoidal twinkle over a 6s cycle, gold halos on the
  // brighter ones, drawn on a fixed full-screen canvas behind the app.
  interface Props {
    starCount?: number;
  }
  let { starCount = 70 }: Props = $props();

  let canvas: HTMLCanvasElement;

  interface Star {
    dx: number;
    dy: number;
    radius: number;
    phase: number;
    twinkleSpeed: number;
  }

  // Deterministic PRNG (seeded) so the field is stable across renders.
  function mulberry32(seed: number) {
    return () => {
      seed |= 0;
      seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  onMount(() => {
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const rnd = mulberry32(42);
    const stars: Star[] = Array.from({ length: starCount }, () => ({
      dx: rnd(),
      dy: rnd(),
      radius: 0.5 + rnd() * 1.6,
      phase: rnd(),
      twinkleSpeed: 0.5 + rnd() * 1.5
    }));

    let w = 0;
    let h = 0;
    let dpr = 1;
    function resize() {
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      w = window.innerWidth;
      h = window.innerHeight;
      canvas.width = w * dpr;
      canvas.height = h * dpr;
      canvas.style.width = `${w}px`;
      canvas.style.height = `${h}px`;
    }
    resize();
    window.addEventListener('resize', resize);

    const start = performance.now();
    let raf = 0;
    function frame(now: number) {
      const t = ((now - start) / 6000) % 1; // 0..1 over 6s
      ctx!.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx!.clearRect(0, 0, w, h);
      for (const s of stars) {
        const wave = (Math.sin((t * s.twinkleSpeed + s.phase) * 2 * Math.PI) + 1) / 2;
        const opacity = 0.25 + wave * 0.65;
        const cx = s.dx * w;
        const cy = s.dy * h;
        const bright = s.radius > 1.4;
        ctx!.beginPath();
        ctx!.fillStyle = bright ? `rgba(244,199,102,${opacity})` : `rgba(243,236,255,${opacity})`;
        ctx!.arc(cx, cy, s.radius, 0, 2 * Math.PI);
        ctx!.fill();
        if (s.radius > 1.3) {
          ctx!.save();
          ctx!.filter = 'blur(3px)';
          ctx!.beginPath();
          ctx!.fillStyle = `rgba(244,199,102,${opacity * 0.18})`;
          ctx!.arc(cx, cy, s.radius * 2.4, 0, 2 * Math.PI);
          ctx!.fill();
          ctx!.restore();
        }
      }
      raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', resize);
    };
  });
</script>

<div class="bg" aria-hidden="true">
  <div class="orb orb-lilac"></div>
  <div class="orb orb-aurora"></div>
  <canvas bind:this={canvas} class="stars"></canvas>
</div>

<style>
  .bg {
    position: fixed;
    inset: 0;
    z-index: 0;
    pointer-events: none;
    overflow: hidden;
  }
  .stars {
    position: absolute;
    inset: 0;
  }
  .orb {
    position: absolute;
    border-radius: 50%;
  }
  .orb-lilac {
    top: -120px;
    right: -80px;
    width: 320px;
    height: 320px;
    background: radial-gradient(circle, rgba(183, 156, 237, 0.22) 0%, rgba(183, 156, 237, 0) 70%);
  }
  .orb-aurora {
    bottom: -160px;
    left: -120px;
    width: 360px;
    height: 360px;
    background: radial-gradient(circle, rgba(127, 224, 212, 0.1) 0%, rgba(127, 224, 212, 0) 70%);
  }
</style>
