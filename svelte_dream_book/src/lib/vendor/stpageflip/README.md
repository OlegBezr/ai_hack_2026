# Vendored StPageFlip (patched)

This is a copy of [StPageFlip](https://github.com/Nodlik/StPageFlip) **with our
touch patch applied** (`UI/UI.ts` — grab the page corner immediately on
`touchstart` instead of after a 250 ms hold, so finger-drag flipping works on
iPad/iPhone, not just with a mouse).

It's imported straight from TypeScript source (Vite/esbuild transpiles it; the
cross-file `const enum`s are preserved via `preserveConstEnums` in
`vite.config.ts`). Importing source rather than an npm build is what lets us ship
the fork's patch without a separate build step.

Upstream + patch notes live in `/Users/olegbezr/Code/js_books`.
