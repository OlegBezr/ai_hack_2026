/**
 * Web Audio engine for the Deepgram Voice Agent loop — a TypeScript port of
 * Flutter's `voice_audio_web.dart`.
 *
 * Two jobs, two `AudioContext`s:
 *
 *  - **Capture** — open the mic, run it through a `ScriptProcessorNode`, downmix
 *    to mono linear16 at 16 kHz, and hand each chunk to the WebSocket via
 *    `startCapture`'s callback. The context is created at the agent's input
 *    sample rate so the browser resamples for us.
 *  - **Playback** — the agent streams back raw linear16 at 24 kHz; `play`
 *    decodes each chunk into an `AudioBuffer` and schedules it on a moving cursor
 *    so consecutive chunks butt up seamlessly. `clearPlayback` stops everything
 *    in flight, which is how barge-in (cutting the agent off when the user
 *    speaks) is implemented.
 *
 * `ScriptProcessorNode` is deprecated in favour of `AudioWorklet`, but the
 * worklet path needs a separately-served JS module; the processor keeps this
 * self-contained, which is the right trade for the reader.
 */

// 16 kHz mono in, 24 kHz mono out — matches the Settings message VoiceAgent sends.
const INPUT_SAMPLE_RATE = 16000;
const OUTPUT_SAMPLE_RATE = 24000;

export class VoiceAudioEngine {
  private inCtx: AudioContext | null = null;
  private outCtx: AudioContext | null = null;
  private stream: MediaStream | null = null;
  private source: MediaStreamAudioSourceNode | null = null;
  private processor: ScriptProcessorNode | null = null;

  /** Playback cursor (in the output context's clock) where the next chunk should
   * start, so queued chunks play gaplessly. */
  private nextStart = 0;

  /** Sources currently scheduled/playing, so `clearPlayback` can stop them. */
  private active = new Set<AudioBufferSourceNode>();

  private stopped = false;

  /**
   * Open the mic and begin emitting 16 kHz mono PCM16 (little-endian) chunks.
   *
   * Must be called from a user gesture (the chat opens on a button tap) so both
   * `getUserMedia` and the suspended-by-autoplay-policy context unlock.
   */
  async startCapture(onChunk: (pcm16le: Uint8Array) => void): Promise<void> {
    const inCtx = new AudioContext({ sampleRate: INPUT_SAMPLE_RATE });
    this.inCtx = inCtx;
    await inCtx.resume();

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    this.stream = stream;
    if (this.stopped) {
      // Disposed mid-permission-prompt — release the mic we just acquired.
      this.stopTracks();
      return;
    }

    const source = inCtx.createMediaStreamSource(stream);
    const processor = inCtx.createScriptProcessor(4096, 1, 1);
    this.source = source;
    this.processor = processor;

    processor.onaudioprocess = (event) => {
      const input = event.inputBuffer.getChannelData(0);
      onChunk(float32ToPcm16(input));
    };

    // ScriptProcessorNode only fires while connected to the graph; routing it to
    // the destination keeps it pumping (it contributes silence).
    source.connect(processor);
    processor.connect(inCtx.destination);
  }

  /** Queue a raw linear16 (24 kHz, mono, little-endian) chunk for playback. */
  play(pcm16le: Uint8Array): void {
    if (this.stopped || pcm16le.byteLength < 2) return;
    const outCtx = (this.outCtx ??= new AudioContext({ sampleRate: OUTPUT_SAMPLE_RATE }));

    const samples = pcm16ToFloat32(pcm16le);
    const buffer = outCtx.createBuffer(1, samples.length, OUTPUT_SAMPLE_RATE);
    buffer.copyToChannel(samples as Float32Array<ArrayBuffer>, 0);

    const source = outCtx.createBufferSource();
    source.buffer = buffer;
    source.connect(outCtx.destination);

    const now = outCtx.currentTime;
    const startAt = this.nextStart < now ? now : this.nextStart;
    this.nextStart = startAt + buffer.duration;

    this.active.add(source);
    source.onended = () => this.active.delete(source);
    source.start(startAt);
  }

  /** Stop and discard any audio queued for playback (barge-in). */
  clearPlayback(): void {
    for (const source of this.active) {
      try {
        source.stop();
      } catch {
        // Already stopped/ended — fine.
      }
    }
    this.active.clear();
    this.nextStart = 0;
  }

  /** Tear everything down: stop the mic, drop both contexts, free the graph. */
  async stop(): Promise<void> {
    this.stopped = true;
    this.clearPlayback();
    this.stopTracks();
    try {
      this.processor?.disconnect();
      this.source?.disconnect();
    } catch {
      /* ignore */
    }
    if (this.processor) this.processor.onaudioprocess = null;
    this.processor = null;
    this.source = null;
    try {
      await this.inCtx?.close();
      await this.outCtx?.close();
    } catch {
      /* ignore */
    }
    this.inCtx = null;
    this.outCtx = null;
  }

  private stopTracks(): void {
    this.stream?.getTracks().forEach((track) => track.stop());
    this.stream = null;
  }
}

function pcm16ToFloat32(bytes: Uint8Array): Float32Array {
  const count = bytes.byteLength >> 1;
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const out = new Float32Array(count);
  for (let i = 0; i < count; i++) {
    out[i] = view.getInt16(i * 2, true) / 32768.0;
  }
  return out;
}

function float32ToPcm16(input: Float32Array): Uint8Array {
  const out = new DataView(new ArrayBuffer(input.length * 2));
  for (let i = 0; i < input.length; i++) {
    let sample = input[i];
    if (sample < -1.0) sample = -1.0;
    else if (sample > 1.0) sample = 1.0;
    out.setInt16(i * 2, Math.round(sample * 32767), true);
  }
  return new Uint8Array(out.buffer);
}
