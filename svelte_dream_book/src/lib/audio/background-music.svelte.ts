/**
 * App-wide background music, mirroring the Flutter `BackgroundMusicController`.
 * A single looping <audio> element shared across the app (created lazily in the
 * browser). Autoplay can't start until a user gesture, so `ensureStarted()` is
 * idempotent and called from the first interaction (mute toggle / track pick)
 * and on screen mounts.
 */

export interface MusicTrack {
  label: string;
  asset: string;
}

const VOLUME = 0.3;

export const TRACKS: MusicTrack[] = [
  { label: 'Dreamy', asset: '/audio/Lilac Skies - Dreamy [Thematic].mp3' },
  { label: 'Magical', asset: '/audio/Lilac Skies - Magical [Thematic].mp3' },
  { label: 'Dozing Off', asset: '/audio/Damien Sebe - dozing off [Thematic].mp3' }
];

class BackgroundMusic {
  trackIndex = $state(0);
  muted = $state(false);

  private audio: HTMLAudioElement | null = null;
  private loadedIndex = -1;

  get track(): MusicTrack {
    return TRACKS[this.trackIndex];
  }

  private el(): HTMLAudioElement {
    if (!this.audio) {
      const a = new Audio();
      a.loop = true;
      a.preload = 'auto';
      this.audio = a;
    }
    return this.audio;
  }

  /** Idempotent: load the current track if needed and play unless muted. */
  async ensureStarted(): Promise<void> {
    if (typeof window === 'undefined') return;
    const a = this.el();
    try {
      if (this.loadedIndex !== this.trackIndex) {
        a.src = encodeURI(this.track.asset);
        this.loadedIndex = this.trackIndex;
      }
      a.volume = this.muted ? 0 : VOLUME;
      if (!this.muted && a.paused) await a.play();
    } catch {
      // Autoplay blocked / asset missing — never break the app.
    }
  }

  /** Pause without changing mute state (used while reading). */
  pause(): void {
    this.audio?.pause();
  }

  async toggleMute(): Promise<void> {
    this.muted = !this.muted;
    const a = this.el();
    if (this.muted) {
      a.volume = 0;
      a.pause();
    } else {
      a.volume = VOLUME;
      await this.ensureStarted();
    }
  }

  async selectTrack(index: number): Promise<void> {
    if (index < 0 || index >= TRACKS.length) return;
    if (index === this.trackIndex && this.loadedIndex === index) return;
    this.trackIndex = index;
    const a = this.el();
    try {
      a.pause();
      a.src = encodeURI(this.track.asset);
      this.loadedIndex = index;
      a.volume = this.muted ? 0 : VOLUME;
      if (!this.muted) await a.play();
    } catch {
      // ignore
    }
  }
}

export const backgroundMusic = new BackgroundMusic();
