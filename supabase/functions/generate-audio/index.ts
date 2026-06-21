// POST /functions/v1/generate-audio
// Body: { page_id, text? }
// Verifies page ownership, synthesizes speech via Deepgram, uploads the MP3 to
// the `audio` bucket, and stamps page.audio_url. Returns { audio_url }.
//
// CORS, per-request Sentry scope, and error→Response shaping all live in
// serveWithSentry (../_shared/sentry.ts) — this file is just the business logic.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { ErrorResponse, getAuthenticatedUser, serviceClient } from "../_shared/auth.ts";
import { speak } from "../_shared/deepgram.ts";
import { publicUrl } from "../_shared/storage.ts";
import { breadcrumb, jsonResponse, serveWithSentry, setTags, setUser } from "../_shared/sentry.ts";

const BUCKET = "audio";

serveWithSentry("generate-audio", async (req) => {
  const { user } = await getAuthenticatedUser(req);
  setUser(user.id);

  const body = await req.json().catch(() => ({})) as {
    page_id?: string;
    text?: string;
  };
  const pageId = body.page_id;
  if (!pageId) {
    throw { error: "page_id is required", status: 400 } as ErrorResponse;
  }
  setTags({ page_id: pageId });
  breadcrumb("audio", "request", { page_id: pageId });

  const admin = serviceClient();

  const { data: page, error: pageError } = await admin
    .from("page")
    .select("id, story_id, text, story:story_id(author_id)")
    .eq("id", pageId)
    .single();

  if (pageError || !page) {
    throw { error: "Page not found", status: 404 } as ErrorResponse;
  }

  const story = Array.isArray(page.story) ? page.story[0] : page.story;
  if (!story || story.author_id !== user.id) {
    throw { error: "Forbidden: you do not own this story", status: 403 } as ErrorResponse;
  }

  const storyId = page.story_id;
  setTags({ story_id: storyId });
  const text = (body.text ?? page.text ?? "").trim();
  if (!text) {
    throw { error: "No text to synthesize", status: 400 } as ErrorResponse;
  }

  const mp3 = await speak(text);

  const path = `${user.id}/${storyId}/${pageId}.mp3`;
  const { error: uploadError } = await admin.storage
    .from(BUCKET)
    .upload(path, mp3, { contentType: "audio/mpeg", upsert: true });
  if (uploadError) {
    throw { error: `Upload failed: ${uploadError.message}`, status: 500 } as ErrorResponse;
  }

  const audioUrl = publicUrl(BUCKET, path);

  const { error: updateError } = await admin
    .from("page")
    .update({ audio_url: audioUrl })
    .eq("id", pageId);
  if (updateError) {
    throw { error: `Update failed: ${updateError.message}`, status: 500 } as ErrorResponse;
  }

  return jsonResponse({ audio_url: audioUrl });
});
