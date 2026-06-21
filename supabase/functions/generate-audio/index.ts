// POST /functions/v1/generate-audio
// Body: { page_id, text? }
// Verifies page ownership, synthesizes speech via Deepgram, uploads the MP3 to
// the `audio` bucket, and stamps page.audio_url. Returns { audio_url }.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { ErrorResponse, getAuthenticatedUser, serviceClient } from "../_shared/auth.ts";
import { speak } from "../_shared/deepgram.ts";
import { publicUrl } from "../_shared/storage.ts";

const BUCKET = "audio";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user } = await getAuthenticatedUser(req);

    const body = await req.json().catch(() => ({})) as {
      page_id?: string;
      text?: string;
    };
    const pageId = body.page_id;
    if (!pageId) {
      throw { error: "page_id is required", status: 400 } as ErrorResponse;
    }

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
  } catch (err) {
    if (err && typeof err === "object" && "status" in err && "error" in err) {
      const e = err as ErrorResponse;
      return jsonResponse({ error: e.error }, e.status);
    }
    console.error("generate-audio error:", err);
    const message = err instanceof Error ? err.message : "An unexpected error occurred";
    return jsonResponse({ error: message }, 500);
  }
});
