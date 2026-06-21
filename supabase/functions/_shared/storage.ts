// Builds a browser-reachable public Storage URL.
//
// Inside the local edge runtime, SUPABASE_URL points at the internal Docker
// hostname (http://kong:8000), so storage.getPublicUrl() returns URLs that the
// browser cannot reach. We construct the public URL from an externally-reachable
// base instead. Locally that defaults to http://127.0.0.1:54321; in production
// set SUPABASE_PUBLIC_URL to the project URL.
export function publicUrl(bucket: string, path: string): string {
  const base = (Deno.env.get("SUPABASE_PUBLIC_URL") ?? "http://127.0.0.1:54321")
    .replace(/\/$/, "");
  return `${base}/storage/v1/object/public/${bucket}/${path}`;
}
