import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';

/**
 * App-wide background music, mirroring the Flutter `BackgroundMusicController`.
 * A single looping <audio> element shared across screens, at 30% volume, with
 * mute + track selection. Browsers block autoplay until a user gesture, so
 * `ensureStarted()` is called from the scaffold and silently no-ops if blocked.
 */
export interface MusicTrack {
  label: string;
  src: string;
}

// eslint-disable-next-line react-refresh/only-export-components
export const TRACKS: MusicTrack[] = [
  { label: 'Dreamy', src: '/audio/Lilac Skies - Dreamy [Thematic].mp3' },
  { label: 'Magical', src: '/audio/Lilac Skies - Magical [Thematic].mp3' },
  { label: 'Dozing Off', src: '/audio/Damien Sebe - dozing off [Thematic].mp3' },
];

const VOLUME = 0.3;

interface MusicApi {
  trackIndex: number;
  muted: boolean;
  ensureStarted: () => void;
  pause: () => void;
  toggleMute: () => void;
  selectTrack: (index: number) => void;
}

const MusicContext = createContext<MusicApi | null>(null);

export function BackgroundMusicProvider({ children }: { children: ReactNode }) {
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [trackIndex, setTrackIndex] = useState(0);
  const [muted, setMuted] = useState(false);

  // Create the shared audio element once.
  if (audioRef.current === null && typeof Audio !== 'undefined') {
    const el = new Audio(TRACKS[0].src);
    el.loop = true;
    el.volume = VOLUME;
    el.preload = 'auto';
    audioRef.current = el;
  }

  useEffect(() => {
    const el = audioRef.current;
    return () => {
      el?.pause();
    };
  }, []);

  const ensureStarted = useCallback(() => {
    const el = audioRef.current;
    if (!el || muted) return;
    el.volume = VOLUME;
    void el.play().catch(() => {
      /* autoplay blocked until a user gesture — ignore */
    });
  }, [muted]);

  const pause = useCallback(() => {
    audioRef.current?.pause();
  }, []);

  const toggleMute = useCallback(() => {
    const el = audioRef.current;
    setMuted((m) => {
      const next = !m;
      if (el) {
        if (next) {
          el.pause();
        } else {
          el.volume = VOLUME;
          void el.play().catch(() => {});
        }
      }
      return next;
    });
  }, []);

  const selectTrack = useCallback(
    (index: number) => {
      if (index < 0 || index >= TRACKS.length) return;
      const el = audioRef.current;
      setTrackIndex(index);
      if (el) {
        el.pause();
        el.src = TRACKS[index].src;
        el.load();
        if (!muted) {
          el.volume = VOLUME;
          void el.play().catch(() => {});
        }
      }
    },
    [muted],
  );

  const api = useMemo<MusicApi>(
    () => ({ trackIndex, muted, ensureStarted, pause, toggleMute, selectTrack }),
    [trackIndex, muted, ensureStarted, pause, toggleMute, selectTrack],
  );

  return <MusicContext.Provider value={api}>{children}</MusicContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useBackgroundMusic(): MusicApi {
  const ctx = useContext(MusicContext);
  if (!ctx) throw new Error('useBackgroundMusic must be used within a BackgroundMusicProvider');
  return ctx;
}
