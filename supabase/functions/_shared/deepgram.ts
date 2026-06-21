// Deepgram TTS — port of DeepgramService.speak from deepgram_service.dart.
// POST text to /v1/speak (model aura-2-thalia-en) and return the raw MP3 bytes.

import { logInfo, logWarn, measure, setTags, withSpan } from "./sentry.ts";

const SPEAK_ENDPOINT = "https://api.deepgram.com/v1/speak";
const LISTEN_ENDPOINT = "https://api.deepgram.com/v1/listen";
const GRANT_ENDPOINT = "https://api.deepgram.com/v1/auth/grant";
const TTS_MODEL = "aura-2-thalia-en";
// How long a minted Voice Agent token stays valid. Short by design: the browser
// mints one right before opening the WebSocket, so a leaked token is nearly
// worthless. Deepgram caps `ttl_seconds` at 3600.
const VOICE_TOKEN_TTL_SECONDS = 60;
// nova-3 is Deepgram's latest general STT model; smart_format adds
// punctuation/capitalisation so the transcript reads as a usable prompt.
const STT_MODEL = "nova-3";
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

/**
 * Transcribe a recorded audio clip — port of DeepgramService.transcribe from
 * deepgram_service.dart. POST the raw bytes to /v1/listen and return the
 * best-alternative transcript (empty string for silence).
 *
 * `contentType` should match how the clip was recorded (the web client records
 * WebM/Opus, so `audio/webm`); Deepgram also sniffs most containers.
 */
export async function transcribe(
  audio: Uint8Array,
  contentType = "audio/webm",
  model: string = STT_MODEL,
): Promise<string> {
  const key = Deno.env.get("DEEPGRAM_KEY") ?? "";
  if (!key) {
    throw new DeepgramError("DEEPGRAM_KEY is not set.", 500);
  }

  setTags({ deepgram_model: model });

  const startedAt = Date.now();
  return await withSpan("deepgram.listen", "Deepgram STT", async () => {
    const url = `${LISTEN_ENDPOINT}?model=${encodeURIComponent(model)}&smart_format=true`;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Token ${key}`,
        "Content-Type": contentType,
      },
      body: audio,
    });

    const text = await res.text();
    if (res.status >= 400) {
      throw new DeepgramError(`listen failed: ${text}`, res.status);
    }

    let transcript = "";
    try {
      const json = JSON.parse(text);
      transcript =
        (json?.results?.channels?.[0]?.alternatives?.[0]?.transcript as string ?? "").trim();
    } catch {
      throw new DeepgramError(`Unexpected listen response: ${text}`, 502);
    }

    const durationMs = Date.now() - startedAt;
    measure("stt_bytes", audio.byteLength, "byte");
    measure("stt_chars", transcript.length);
    measure("stt_duration_ms", durationMs, "millisecond");
    logInfo("deepgram listen complete", {
      model,
      bytes: audio.byteLength,
      chars: transcript.length,
      duration_ms: durationMs,
    });
    return transcript;
  }, { model, bytes: audio.byteLength });
}

/**
 * Mint a short-lived Deepgram token for the browser to open the Voice Agent
 * WebSocket with. We never ship the long-lived `DEEPGRAM_KEY` to the client;
 * instead an authenticated edge function exchanges it for an ephemeral token
 * here. Returns the token and its lifetime so the caller can relay both.
 */
export async function grantVoiceToken(
  ttlSeconds: number = VOICE_TOKEN_TTL_SECONDS,
): Promise<{ token: string; expiresIn: number }> {
  const key = Deno.env.get("DEEPGRAM_KEY") ?? "";
  if (!key) {
    throw new DeepgramError("DEEPGRAM_KEY is not set.", 500);
  }

  return await withSpan("deepgram.grant", "Deepgram token grant", async () => {
    const res = await fetch(GRANT_ENDPOINT, {
      method: "POST",
      headers: {
        "Authorization": `Token ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ ttl_seconds: ttlSeconds }),
    });

    const text = await res.text();
    if (res.status >= 400) {
      throw new DeepgramError(`grant failed: ${text}`, res.status);
    }

    let token = "";
    let expiresIn = ttlSeconds;
    try {
      const json = JSON.parse(text);
      token = (json?.access_token as string) ?? "";
      if (typeof json?.expires_in === "number") expiresIn = json.expires_in;
    } catch {
      throw new DeepgramError(`Unexpected grant response: ${text}`, 502);
    }
    if (!token) {
      throw new DeepgramError("grant response missing access_token", 502);
    }

    logInfo("deepgram grant complete", { expires_in: expiresIn });
    return { token, expiresIn };
  }, { ttl_seconds: ttlSeconds });
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
