import { sentrySvelteKit } from "@sentry/sveltekit";
import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sentrySvelteKit({
    org: "ai-hack-2026",
    project: "javascript-sveltekit"
  }), tailwindcss(), sveltekit()],
  server: {
    host: true, // expose on LAN for real-device testing (iPad/iPhone)
    port: 5190,
    // Vite blocks requests whose Host header it doesn't recognise. ngrok serves
    // the app under a *.ngrok-free.app / *.ngrok.app host, so allow those (plus
    // anything set via VITE_TUNNEL_HOST, e.g. a reserved/static ngrok domain).
    allowedHosts: [
      '.ngrok-free.app',
      '.ngrok.app',
      '.ngrok.io',
      ...(process.env.VITE_TUNNEL_HOST ? [process.env.VITE_TUNNEL_HOST] : [])
    ],
    // When served over the HTTPS tunnel, the HMR websocket must also go over
    // wss on 443 through the same host, or hot reload silently fails.
    hmr: process.env.VITE_TUNNEL_HOST
      ? { protocol: 'wss', host: process.env.VITE_TUNNEL_HOST, clientPort: 443 }
      : undefined
  }
});
