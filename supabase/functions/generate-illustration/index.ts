// POST /functions/v1/generate-illustration
// Body: { page_id, prompt }
// Verifies page ownership, calls Midjourney, and stamps page.illustration_url
// with the Midjourney CDN URL. Returns { illustration_url, job_id, images }.
//
// We do NOT re-host the image in Supabase storage: cdn.midjourney.com is behind
// Cloudflare, which blocks server-side (non-browser TLS fingerprint) downloads
// with a 403. The app loads the CDN URL directly (Dart's http stack is allowed).
//
// CORS, per-request Sentry scope, and error→Response shaping all live in
// serveWithSentry (../_shared/sentry.ts) — this file is just the business logic.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { ErrorResponse, getAuthenticatedUser, serviceClient } from "../_shared/auth.ts";
import { generateImage } from "../_shared/midjourney.ts";
import { breadcrumb, jsonResponse, serveWithSentry, setTags, setUser } from "../_shared/sentry.ts";

serveWithSentry("generate-illustration", async (req) => {
  const { user } = await getAuthenticatedUser(req);
  setUser(user.id);

  const body = await req.json().catch(() => ({})) as {
    page_id?: string;
    prompt?: string;
  };
  const pageId = body.page_id;
  const prompt = body.prompt;
  if (!pageId || !prompt) {
    throw { error: "page_id and prompt are required", status: 400 } as ErrorResponse;
  }
  setTags({ page_id: pageId });
  breadcrumb("illustration", "request", { page_id: pageId, prompt_len: prompt.length });

  const admin = serviceClient();

  // Fetch the page joined to its story to verify ownership.
  const { data: page, error: pageError } = await admin
    .from("page")
    .select("id, story_id, story:story_id(author_id)")
    .eq("id", pageId)
    .single();

  if (pageError || !page) {
    throw { error: "Page not found", status: 404 } as ErrorResponse;
  }

  // story:story_id(...) is returned as an object (to-one); be defensive.
  const story = Array.isArray(page.story) ? page.story[0] : page.story;
  if (!story || story.author_id !== user.id) {
    throw { error: "Forbidden: you do not own this story", status: 403 } as ErrorResponse;
  }
  setTags({ story_id: page.story_id });

  // Generate the image. We store the Midjourney CDN URL of the first grid
  // image directly (no re-hosting — see the header note).
  const { jobId, images } = await generateImage(prompt);
  if (images.length === 0) {
    throw { error: "Midjourney returned no images", status: 502 } as ErrorResponse;
  }

  // MJ returns a 2x2 grid (4 takes on the prompt); we auto-pick #1. The full
  // set is still returned to the caller in `images` below.
  // TODO(optional): let the user pick from the grid instead of auto-#1 —
  // show `images` in the UI, then stamp the chosen URL. Backend already
  // returns the array; only the Flutter picker is missing. MJ variance is
  // high, so #1 is often not the best of the 4.
  const illustrationUrl = images[0];
  console.log(`Generated illustration for page ${pageId}: ${illustrationUrl}`);

  const { error: updateError } = await admin
    .from("page")
    .update({ illustration_url: illustrationUrl })
    .eq("id", pageId);
  if (updateError) {
    throw { error: `Update failed: ${updateError.message}`, status: 500 } as ErrorResponse;
  }

  return jsonResponse({
    illustration_url: illustrationUrl,
    job_id: jobId,
    images,
  });
});
