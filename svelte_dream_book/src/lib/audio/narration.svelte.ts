/**
 * Per-page narration playback, mirroring the Flutter `PageNarrationController`.
 * One <audio> element scoped to the reader screen. `openPage` is called on every
 * page turn; if autoplay is on and the page has audio, it plays immediately.
 * Every operation swallows errors — narration must never break reading.
 */
export class Narration {
  autoplay = $state(true);
  playing = $state(false);
  loading = $state(false);
  position = $state(0); // seconds
  duration = $state(0); // seconds

  // Reactive: the NarrationBar reads `hasAudio` (derived from this) to toggle the
  // "No narration on this page" message and the disabled button states. A plain
  // field wouldn't trigger re-renders on page turns, leaving the bar stale.
  private currentUrl = $state<string | null>(null);
  private audio: HTMLAudioElement | null = null;

  private el(): HTMLAudioElement {
    if (!this.audio) {
      const a = new Audio();
      a.preload = 'auto';
      a.addEventListener('play', () => (this.playing = true));
      a.addEventListener('pause', () => (this.playing = false));
      a.addEventListener('ended', () => (this.playing = false));
      a.addEventListener('waiting', () => (this.loading = true));
      a.addEventListener('playing', () => (this.loading = false));
      a.addEventListener('canplay', () => (this.loading = false));
      a.addEventListener('timeupdate', () => (this.position = a.currentTime));
      a.addEventListener(
        'loadedmetadata',
        () => (this.duration = Number.isFinite(a.duration) ? a.duration : 0)
      );
      this.audio = a;
    }
    return this.audio;
  }

  get hasAudio(): boolean {
    return this.currentUrl !== null && this.currentUrl !== '';
  }

  get completed(): boolean {
    const a = this.audio;
    return !!a && a.duration > 0 && a.ended;
  }

  /** Load (and maybe autoplay) the narration for the freshly-opened page. */
  async openPage(audioUrl: string | null | undefined): Promise<void> {
    const url = audioUrl && audioUrl.length > 0 ? audioUrl : null;
    if (url === this.currentUrl) return;
    this.currentUrl = url;
    this.position = 0;
    this.duration = 0;

    const a = this.el();
    try {
      a.pause();
      if (url === null) {
        this.playing = false;
        return;
      }
      a.src = url;
      this.loading = true;
      if (this.autoplay) await a.play();
    } catch {
      this.loading = false;
    }
  }

  async togglePlay(): Promise<void> {
    if (!this.hasAudio) return;
    const a = this.el();
    try {
      if (this.playing) {
        a.pause();
      } else {
        if (a.ended) a.currentTime = 0;
        await a.play();
      }
    } catch {
      /* ignore */
    }
  }

  async replay(): Promise<void> {
    if (!this.hasAudio) return;
    const a = this.el();
    try {
      a.currentTime = 0;
      await a.play();
    } catch {
      /* ignore */
    }
  }

  seek(seconds: number): void {
    if (!this.hasAudio) return;
    try {
      this.el().currentTime = seconds;
      this.position = seconds;
    } catch {
      /* ignore */
    }
  }

  setAutoplay(value: boolean): void {
    if (value === this.autoplay) return;
    this.autoplay = value;
    if (value && this.hasAudio && !this.playing) void this.togglePlay();
  }

  dispose(): void {
    const a = this.audio;
    if (a) {
      a.pause();
      a.src = '';
    }
    this.audio = null;
  }
}
