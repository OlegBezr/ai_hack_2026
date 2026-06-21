import adapter from '@sveltejs/adapter-vercel';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    // The app runs entirely client-side (see src/routes/+layout.ts: ssr=false),
    // so this is really a static SPA. adapter-vercel auto-detects on Vercel
    // (no output-dir/preset overrides needed) and serves the app shell for deep
    // links like /read/:id, letting the client router take over.
    adapter: adapter()
  }
};

export default config;
