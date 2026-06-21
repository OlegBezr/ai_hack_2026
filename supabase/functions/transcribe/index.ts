// POST /functions/v1/transcribe
// Body: { audio_base64, mime? }
// Transcribes a recorded audio clip via Deepgram STT and returns { transcript }.
//
// The Deepgram key stays server-side: browsers can't be trusted with a paid API
// key, so the web "Tell a Story" screen records audio and hands the bytes here
// (base64 in JSON) instead of calling Deepgram directly like the Flutter app.
//
// CORS, per-request Sentry scope, and error→Response shaping all live in
// serveWithSentry (../_shared/sentry.ts) — this file is just the business logic.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { ErrorResponse, getAuthenticatedUser } from "../_shared/auth.ts";
import { transcribe } from "../_shared/deepgram.ts";
import { breadcrumb, jsonResponse, serveWithSentry, setUser } from "../_shared/sentry.ts";

// Guard against an oversized payload pinning the isolate. ~8 MB of base64 is
// many minutes of Opus audio — far more than a single spoken story needs.
const MAX_BASE64_CHARS = 8_000_000;

serveWithSentry("transcribe", async (req) => {
  const { user } = await getAuthenticatedUser(req);
  setUser(user.id);

  const body = await req.json().catch(() => ({})) as {
    audio_base64?: string;
    mime?: string;
  };

  const b64 = body.audio_base64 ?? "";
  if (!b64) {
    throw { error: "audio_base64 is required", status: 400 } as ErrorResponse;
  }
  if (b64.length > MAX_BASE64_CHARS) {
    throw { error: "Recording is too long; please keep it under a few minutes.", status: 413 } as ErrorResponse;
  }

  let audio: Uint8Array;
  try {
    audio = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  } catch {
    throw { error: "audio_base64 is not valid base64", status: 400 } as ErrorResponse;
  }
  breadcrumb("transcribe", "request", { bytes: audio.byteLength });

  const transcript = await transcribe(audio, body.mime ?? "audio/webm");
  return jsonResponse({ transcript });
});
