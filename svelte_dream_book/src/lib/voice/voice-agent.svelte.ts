import { VoiceAudioEngine } from './voice-audio';
import { getVoiceAgentToken } from '$lib/generation';

/** High-level phase of the live conversation, surfaced to the UI. */
export type VoiceAgentPhase =
  | 'idle'
  | 'connecting'
  | 'listening'
  | 'thinking'
  | 'speaking'
  | 'error';

/** One line of the running conversation transcript. */
export interface VoiceTurn {
  /** `'user'` or `'assistant'`. */
  role: string;
  text: string;
}

const ENDPOINT = 'wss://agent.deepgram.com/v1/agent/converse';

/**
 * Drives a full **voice-to-voice** conversation against Deepgram's Voice Agent
 * API over a single WebSocket (`wss://agent.deepgram.com/v1/agent/converse`).
 * TypeScript/Svelte port of Flutter's `VoiceAgentController`.
 *
 * The agent runs the whole pipeline server-side: it transcribes the mic audio we
 * stream up (STT), feeds the transcript to a Deepgram-managed LLM primed with the
 * book as its system prompt, and streams synthesized speech back down (TTS) —
 * which we play immediately. Audio plumbing lives in {@link VoiceAudioEngine};
 * this class only speaks the JSON/binary WebSocket protocol.
 *
 * `phase`, `error`, and `transcript` are Svelte 5 runes, so the chat component
 * re-renders on every change.
 */
export class VoiceAgentController {
  phase = $state<VoiceAgentPhase>('idle');
  error = $state<string | null>(null);
  transcript = $state<VoiceTurn[]>([]);

  private ws: WebSocket | null = null;
  private audio: VoiceAudioEngine | null = null;
  private closed = false;

  /**
   * Mint an ephemeral token, open the socket, configure the agent with
   * `systemPrompt` (the book) and an optional spoken `greeting`, then start
   * streaming the mic. Must be called from a user gesture so `getUserMedia` and
   * the autoplay-suspended AudioContext both unlock.
   */
  async connect(systemPrompt: string, greeting?: string): Promise<void> {
    this.setPhase('connecting');
    try {
      const { token } = await getVoiceAgentToken();
      if (this.closed) return;

      // Browsers can't set an Authorization header on a WebSocket, so Deepgram
      // accepts the credential via the subprotocol. An ephemeral grant token
      // uses the Bearer scheme: `Sec-WebSocket-Protocol: bearer, <token>`.
      const ws = new WebSocket(ENDPOINT, ['bearer', token]);
      ws.binaryType = 'arraybuffer';
      this.ws = ws;

      ws.addEventListener('open', () => {
        this.send(this.settings(systemPrompt, greeting));
        void this.startMic();
      });
      ws.addEventListener('message', (e) => this.onMessage(e.data));
      ws.addEventListener('error', () => this.fail('Connection error.'));
      ws.addEventListener('close', () => this.onClose());
    } catch (e) {
      this.fail(`Failed to start voice chat: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  /** Stop the mic, close the socket, and reset to idle. */
  async disconnect(): Promise<void> {
    this.closed = true;
    await this.audio?.stop();
    this.audio = null;
    try {
      this.ws?.close();
    } catch {
      /* ignore */
    }
    this.ws = null;
    if (this.phase !== 'error') this.setPhase('idle');
  }

  // --- WebSocket plumbing ---------------------------------------------------

  private async startMic(): Promise<void> {
    try {
      this.audio = new VoiceAudioEngine();
      await this.audio.startCapture((pcm16le) => {
        // Binary frames on this socket are mic audio going up.
        if (this.ws?.readyState === WebSocket.OPEN) this.ws.send(pcm16le);
      });
      if (this.phase === 'connecting') this.setPhase('listening');
    } catch (e) {
      this.fail(
        `Microphone unavailable: ${e instanceof Error ? e.message : String(e)}`
      );
    }
  }

  private onMessage(data: unknown): void {
    if (typeof data === 'string') {
      this.onControlMessage(data);
    } else if (data instanceof ArrayBuffer) {
      // Binary frames coming down are synthesized speech (linear16 @ 24 kHz).
      this.audio?.play(new Uint8Array(data));
    }
  }

  /** Handle a JSON control event. See Deepgram's Voice Agent message reference. */
  private onControlMessage(raw: string): void {
    let json: Record<string, unknown>;
    try {
      json = JSON.parse(raw);
    } catch {
      return;
    }
    switch (json.type) {
      case 'UserStartedSpeaking':
        // Barge-in: drop any agent speech still queued and listen.
        this.audio?.clearPlayback();
        this.setPhase('listening');
        break;
      case 'AgentThinking':
        this.setPhase('thinking');
        break;
      case 'AgentStartedSpeaking':
        this.setPhase('speaking');
        break;
      case 'AgentAudioDone':
        this.setPhase('listening');
        break;
      case 'ConversationText':
        this.appendTurn(
          (json.role as string) ?? 'assistant',
          ((json.content as string) ?? '').trim()
        );
        break;
      case 'Error':
        this.fail(`Agent error: ${json.description ?? json.message ?? raw}`);
        break;
    }
  }

  private onClose(): void {
    if (this.phase !== 'error' && this.phase !== 'idle') this.setPhase('idle');
  }

  // --- helpers --------------------------------------------------------------

  private appendTurn(role: string, text: string): void {
    if (!text) return;
    const last = this.transcript.at(-1);
    // Deepgram emits one ConversationText per finalized turn, but coalesce
    // consecutive same-role lines just in case.
    if (last && last.role === role) {
      this.transcript = [
        ...this.transcript.slice(0, -1),
        { role, text: `${last.text} ${text}`.trim() }
      ];
    } else {
      this.transcript = [...this.transcript, { role, text }];
    }
  }

  private send(message: unknown): void {
    if (this.ws?.readyState === WebSocket.OPEN) this.ws.send(JSON.stringify(message));
  }

  private settings(systemPrompt: string, greeting?: string) {
    return {
      type: 'Settings',
      audio: {
        input: { encoding: 'linear16', sample_rate: 16000 },
        // `container: none` => raw PCM frames we can hand straight to Web Audio.
        output: { encoding: 'linear16', sample_rate: 24000, container: 'none' }
      },
      agent: {
        language: 'en',
        listen: { provider: { type: 'deepgram', model: 'nova-3' } },
        think: {
          provider: { type: 'open_ai', model: 'gpt-4o-mini' },
          prompt: systemPrompt
        },
        speak: { provider: { type: 'deepgram', model: 'aura-2-thalia-en' } },
        ...(greeting ? { greeting } : {})
      }
    };
  }

  private setPhase(phase: VoiceAgentPhase): void {
    if (this.phase === phase) return;
    this.phase = phase;
    if (phase !== 'error') this.error = null;
  }

  private fail(message: string): void {
    this.error = message;
    this.phase = 'error';
  }
}
