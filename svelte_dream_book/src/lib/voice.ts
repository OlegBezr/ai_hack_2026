import { supabase } from './supabase';

/**
 * Browser voice capture + transcription — the web equivalent of the Flutter
 * `record` + `DeepgramService.transcribe` pair used by the "Tell a Story" flow.
 *
 * We record with the browser's native MediaRecorder (WebM/Opus — instant to
 * start and tiny), then hand the bytes to the `transcribe` edge function, which
 * holds the Deepgram key server-side. Deepgram decodes WebM/Opus fine.
 */

/** Pick a MediaRecorder mime the browser actually supports, preferring Opus. */
function pickMimeType(): string | undefined {
  if (typeof MediaRecorder === 'undefined') return undefined;
  const candidates = ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4', 'audio/ogg;codecs=opus'];
  return candidates.find((t) => MediaRecorder.isTypeSupported(t));
}

/** Whether this browser can record audio at all (needs MediaRecorder + getUserMedia). */
export function canRecord(): boolean {
  return (
    typeof MediaRecorder !== 'undefined' &&
    typeof navigator !== 'undefined' &&
    !!navigator.mediaDevices?.getUserMedia
  );
}

/**
 * A single live recording. Call {@link stop} to end it and get the captured
 * audio as a Blob; the underlying mic stream is released either way.
 */
export class Recording {
  private chunks: Blob[] = [];
  private resolveStop: ((blob: Blob) => void) | null = null;

  private constructor(
    private readonly recorder: MediaRecorder,
    private readonly stream: MediaStream,
    readonly mimeType: string
  ) {
    recorder.ondataavailable = (e) => {
      if (e.data.size > 0) this.chunks.push(e.data);
    };
    recorder.onstop = () => {
      const blob = new Blob(this.chunks, { type: this.mimeType });
      this.releaseTracks();
      this.resolveStop?.(blob);
    };
  }

  /** Request mic access and start recording. Rejects if permission is denied. */
  static async start(): Promise<Recording> {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const mimeType = pickMimeType();
    const recorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined);
    const rec = new Recording(recorder, stream, recorder.mimeType || mimeType || 'audio/webm');
    recorder.start();
    return rec;
  }

  /** Stop recording and resolve with the captured audio. */
  stop(): Promise<Blob> {
    return new Promise((resolve) => {
      this.resolveStop = resolve;
      if (this.recorder.state !== 'inactive') {
        this.recorder.stop();
      } else {
        resolve(new Blob(this.chunks, { type: this.mimeType }));
      }
    });
  }

  /** Abandon the recording and release the mic without producing a Blob. */
  cancel(): void {
    if (this.recorder.state !== 'inactive') this.recorder.stop();
    this.releaseTracks();
  }

  private releaseTracks(): void {
    for (const track of this.stream.getTracks()) track.stop();
  }
}

/** Base64-encode a Blob's bytes (no data: prefix) for JSON transport. */
async function blobToBase64(blob: Blob): Promise<string> {
  const buf = new Uint8Array(await blob.arrayBuffer());
  let binary = '';
  const chunk = 0x8000; // avoid "too many arguments" on String.fromCharCode
  for (let i = 0; i < buf.length; i += chunk) {
    binary += String.fromCharCode(...buf.subarray(i, i + chunk));
  }
  return btoa(binary);
}

/**
 * Send a recorded clip to the `transcribe` edge function and return the text.
 * Returns '' for silence.
 */
export async function transcribeAudio(blob: Blob): Promise<string> {
  if (blob.size === 0) return '';
  const audio_base64 = await blobToBase64(blob);
  // Strip any codecs= suffix; Deepgram only needs the container type.
  const mime = blob.type.split(';')[0] || 'audio/webm';

  const { data, error } = await supabase.functions.invoke('transcribe', {
    body: { audio_base64, mime }
  });
  if (error) {
    const e = error as { message?: string; context?: { error?: string } };
    throw new Error(e.context?.error ?? e.message ?? 'Transcription failed');
  }
  const res = data as { transcript?: string; error?: string };
  if (res?.error) throw new Error(res.error);
  return (res?.transcript ?? '').trim();
}
