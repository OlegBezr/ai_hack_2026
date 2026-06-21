// Deepgram TTS — port of DeepgramService.speak from deepgram_service.dart.
// POST text to /v1/speak (model aura-2-thalia-en) and return the raw MP3 bytes.

import { logInfo, logWarn, measure, setTags, withSpan } from "./sentry.ts";

const SPEAK_ENDPOINT = "https://api.deepgram.com/v1/speak";
const TTS_MODEL = "aura-2-thalia-en";
// A synthesis slower than this is worth a heads-up (still succeeds).
const SLOW_SPEAK_MS = 15_000;

export class DeepgramError extends Error {
  code?: number;
  constructor(message: string, code?: number) {
    super(message);
    this.name = "DeepgramError";
    this.code = code;
  }
}

/** Synthesize `text` to spoken audio and return the raw MP3 bytes. */
export async function speak(
  text: string,
  model: string = TTS_MODEL,
): Promise<Uint8Array> {
  const key = Deno.env.get("DEEPGRAM_KEY") ?? "";
  if (!key) {
    throw new DeepgramError("DEEPGRAM_KEY is not set.", 500);
  }

  setTags({ deepgram_model: model });

  // The span times the TTS call and the surrounding breadcrumbs/logs give any
  // later failure a trail of what Deepgram did (model, payload size, status).
  const startedAt = Date.now();
  return await withSpan("deepgram.speak", "Deepgram TTS", async () => {
    const url = `${SPEAK_ENDPOINT}?model=${encodeURIComponent(model)}`;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Token ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ text }),
    });

    if (res.status >= 400) {
      const body = await res.text();
      throw new DeepgramError(`speak failed: ${body}`, res.status);
    }

    const buffer = await res.arrayBuffer();
    const durationMs = Date.now() - startedAt;
    measure("audio_bytes", buffer.byteLength, "byte");
    measure("tts_chars", text.length);
    measure("tts_duration_ms", durationMs, "millisecond");
    logInfo("deepgram speak complete", {
      model,
      chars: text.length,
      bytes: buffer.byteLength,
      duration_ms: durationMs,
    });
    if (durationMs > SLOW_SPEAK_MS) {
      logWarn("deepgram synthesis slow", { model, duration_ms: durationMs });
    }
    return new Uint8Array(buffer);
  }, { model, chars: text.length });
}
