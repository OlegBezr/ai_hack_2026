// Builds a browser-reachable public Storage URL.
//
// Inside the local edge runtime, SUPABASE_URL points at the internal Docker
// hostname (http://kong:8000), so storage.getPublicUrl() returns URLs that the
// browser cannot reach. We construct the public URL from an externally-reachable
// base instead. Locally SUPABASE_PUBLIC_URL overrides it (default
// http://127.0.0.1:54321). In production SUPABASE_URL is the real public project
// URL (and SUPABASE_* secrets can't be set), so fall back to it.
export function publicUrl(bucket: string, path: string): string {
  const base = (Deno.env.get("SUPABASE_PUBLIC_URL") ??
    Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321")
    .replace(/\/$/, "");
  return `${base}/storage/v1/object/public/${bucket}/${path}`;
}
