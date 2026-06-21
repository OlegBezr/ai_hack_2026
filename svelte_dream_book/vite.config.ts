import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [tailwindcss(), sveltekit()],
  server: {
    host: true, // expose on LAN for real-device testing (iPad/iPhone)
    port: 5190
  },
  esbuild: {
    // The vendored StPageFlip source is plain TS (type-only imports like
    // `Point`, cross-file `const enum`s). Override the per-file transpile so
    // esbuild (a) elides type-only imports — SvelteKit's tsconfig turns on
    // verbatimModuleSyntax, which would otherwise keep them and 500 — and
    // (b) preserves const enums as real runtime objects.
    // String form: esbuild's typed `tsconfigRaw` object omits
    // `preserveConstEnums`, so we pass raw JSON to keep it (and avoid an `any`).
    tsconfigRaw: JSON.stringify({
      compilerOptions: {
        verbatimModuleSyntax: false,
        preserveConstEnums: true
      }
    })
  }
});
