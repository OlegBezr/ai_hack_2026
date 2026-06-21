// POST /functions/v1/generate-illustration
// Body: { page_id, prompt }
// Verifies page ownership, calls Midjourney, uploads the first grid image to the
// `illustrations` bucket, and stamps page.illustration_url. Returns
// { illustration_url, job_id, images }.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { ErrorResponse, getAuthenticatedUser, serviceClient } from "../_shared/auth.ts";
import { generateImage } from "../_shared/midjourney.ts";
import { publicUrl } from "../_shared/storage.ts";

const BUCKET = "illustrations";

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
      prompt?: string;
    };
    const pageId = body.page_id;
    const prompt = body.prompt;
    if (!pageId || !prompt) {
      throw { error: "page_id and prompt are required", status: 400 } as ErrorResponse;
    }

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

    const storyId = page.story_id;

    // Generate the image and download the first grid image.
    const { jobId, images } = await generateImage(prompt);
    if (images.length === 0) {
      throw { error: "Midjourney returned no images", status: 502 } as ErrorResponse;
    }

    const imgRes = await fetch(images[0]);
    if (!imgRes.ok) {
      throw {
        error: `Failed to download image: HTTP ${imgRes.status}`,
        status: 502,
      } as ErrorResponse;
    }
    const bytes = new Uint8Array(await imgRes.arrayBuffer());

    // Upload to storage at <uid>/<story_id>/<page_id>.png.
    const path = `${user.id}/${storyId}/${pageId}.png`;
    const { error: uploadError } = await admin.storage
      .from(BUCKET)
      .upload(path, bytes, { contentType: "image/png", upsert: true });
    if (uploadError) {
      throw { error: `Upload failed: ${uploadError.message}`, status: 500 } as ErrorResponse;
    }

    const illustrationUrl = publicUrl(BUCKET, path);

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
  } catch (err) {
    if (err && typeof err === "object" && "status" in err && "error" in err) {
      const e = err as ErrorResponse;
      return jsonResponse({ error: e.error }, e.status);
    }
    console.error("generate-illustration error:", err);
    const message = err instanceof Error ? err.message : "An unexpected error occurred";
    return jsonResponse({ error: message }, 500);
  }
});
