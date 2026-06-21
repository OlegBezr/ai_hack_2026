import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    // The app runs entirely client-side (see src/routes/+layout.ts: ssr=false),
    // so we ship a fully static SPA. `fallback` makes every unknown path serve
    // index.html, letting the client router handle deep links like /read/:id.
    adapter: adapter({
      fallback: 'index.html'
    })
  }
};

export default config;
