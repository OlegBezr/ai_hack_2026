// Deepgram TTS — port of DeepgramService.speak from deepgram_service.dart.
// POST text to /v1/speak (model aura-2-thalia-en) and return the raw MP3 bytes.

const SPEAK_ENDPOINT = "https://api.deepgram.com/v1/speak";
const TTS_MODEL = "aura-2-thalia-en";

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
  return new Uint8Array(buffer);
}
