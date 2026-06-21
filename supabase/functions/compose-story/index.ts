// POST /functions/v1/compose-story
// Body: { transcript, title?, page_count?, style? }
//
// Turns a spoken/typed story transcript into a finished storybook:
//   1. Calls Anthropic (Claude) to split the transcript into ordered pages,
//      each with an illustration prompt, plus a title and cover-art prompt.
//   2. Creates the `story` row (owned by the caller) and inserts the `page` rows.
//   3. Returns the new story_id plus the pages WITH their illustration prompts,
//      so the app can fan out audio + illustration + cover generation in parallel.
//
// Media (audio/illustrations/cover) is intentionally NOT generated here: each
// Midjourney/Deepgram call takes many seconds, and doing 10+ inline would blow
// the edge function's wall-clock budget. The Flutter client kicks those off in
// parallel via the existing generate-audio / generate-illustration /
// generate-texture functions, which gives per-page progress and resilience.
//
// CORS, per-request Sentry scope, and error→Response shaping all live in
// serveWithSentry (../_shared/sentry.ts) — this file is just the business logic.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { ErrorResponse, getAuthenticatedUser, serviceClient } from "../_shared/auth.ts";
import { AnthropicError, composeStoryFromTranscript } from "../_shared/anthropic.ts";
import { breadcrumb, jsonResponse, serveWithSentry, setTags, setUser, withSpan } from "../_shared/sentry.ts";

serveWithSentry("compose-story", async (req) => {
  const { user } = await getAuthenticatedUser(req);
  setUser(user.id);

  const body = await req.json().catch(() => ({})) as {
    transcript?: string;
    title?: string;
    page_count?: number;
    style?: Record<string, unknown>;
  };

  const transcript = (body.transcript ?? "").trim();
  if (transcript.length < 10) {
    throw {
      error: "transcript is required (tell the story first).",
      status: 400,
    } as ErrorResponse;
  }
  setTags({ page_count: body.page_count ?? 0 });
  breadcrumb("compose", "request", { transcript_chars: transcript.length });

  // 1. Compose the story with Claude (structured tool output). Surface the
  //    upstream HTTP status as an ErrorResponse so serveWithSentry shapes it
  //    (and reports 5xx) just like every other failure path.
  let composed;
  try {
    composed = await withSpan("anthropic", "composeStoryFromTranscript", () =>
      composeStoryFromTranscript(transcript, {
        title: body.title,
        pageCount: body.page_count,
      }));
  } catch (err) {
    if (err instanceof AnthropicError) {
      throw { error: err.message, status: err.status ?? 500 } as ErrorResponse;
    }
    throw err;
  }

  const admin = serviceClient();

  // 2a. Create the story (service role bypasses RLS, so set the owner explicitly).
  const { data: story, error: storyError } = await admin
    .from("story")
    .insert({
      title: composed.title,
      author_id: user.id,
      created_by: user.id,
      updated_by: user.id,
      // The model picks a style that fits the mood + art; an explicit caller
      // override (body.style) wins if provided.
      style: body.style ?? composed.style,
    })
    .select("id")
    .single();

  if (storyError || !story) {
    throw {
      error: `Failed to create story: ${storyError?.message}`,
      status: 500,
    } as ErrorResponse;
  }

  const storyId = story.id as string;
  setTags({ story_id: storyId });

  // 2b. Insert the pages in order.
  const pageRows = composed.pages.map((p, i) => ({
    story_id: storyId,
    position: i,
    text: p.text,
    created_by: user.id,
    updated_by: user.id,
  }));

  const { data: pages, error: pagesError } = await admin
    .from("page")
    .insert(pageRows)
    .select("id, position");

  if (pagesError || !pages) {
    // Roll back the orphaned story so we don't leave a half-made book.
    await admin.from("story").delete().eq("id", storyId);
    throw {
      error: `Failed to create pages: ${pagesError?.message}`,
      status: 500,
    } as ErrorResponse;
  }

  // 3. Stitch each page id back to its prompt (ordered by position) so the
  //    client can immediately request the matching illustration + audio.
  const byPosition = new Map<number, string>();
  for (const row of pages) byPosition.set(row.position as number, row.id as string);

  const responsePages = composed.pages.map((p, i) => ({
    id: byPosition.get(i),
    position: i,
    text: p.text,
    illustration_prompt: p.illustration_prompt,
  }));

  return jsonResponse({
    story_id: storyId,
    title: composed.title,
    cover_prompt: composed.cover_prompt,
    style: composed.style,
    pages: responsePages,
  });
});
