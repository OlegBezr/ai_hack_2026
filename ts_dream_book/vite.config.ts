import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// StPageFlip is vendored as TypeScript source under src/vendor/stpageflip. Its
// cross-file `const enum`s are preserved as runtime enums by esbuild's per-file
// transform (verified in the running app), so no extra config is needed.
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    host: true,
    port: 5181,
  },
});
