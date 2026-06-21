import { useCallback, useEffect, useRef, useState } from 'react';

/**
 * Per-page narration player, scoped to the reader screen — the React analogue
 * of the Flutter `PageNarrationController`. Owns a single <audio> element,
 * plays the open page's `audio_url`, and (when autoplay is on) starts on page
 * turn. Re-opening the same URL is a no-op so rapid flips don't restart audio.
 */
export interface NarrationState {
  hasAudio: boolean;
  isPlaying: boolean;
  isLoading: boolean;
  autoplay: boolean;
  position: number; // seconds
  duration: number; // seconds
}

export interface NarrationApi extends NarrationState {
  openPage: (audioUrl: string | null | undefined) => void;
  togglePlay: () => void;
  replay: () => void;
  seek: (seconds: number) => void;
  setAutoplay: (value: boolean) => void;
}

export function usePageNarration(): NarrationApi {
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const currentUrlRef = useRef<string | null>(null);
  const autoplayRef = useRef(true);

  const [state, setState] = useState<NarrationState>({
    hasAudio: false,
    isPlaying: false,
    isLoading: false,
    autoplay: true,
    position: 0,
    duration: 0,
  });

  // Lazily create the element and wire its events once.
  if (audioRef.current === null && typeof Audio !== 'undefined') {
    audioRef.current = new Audio();
  }

  useEffect(() => {
    const el = audioRef.current;
    if (!el) return;
    const onTime = () => setState((s) => ({ ...s, position: el.currentTime }));
    const onMeta = () =>
      setState((s) => ({ ...s, duration: Number.isFinite(el.duration) ? el.duration : 0 }));
    const onPlay = () => setState((s) => ({ ...s, isPlaying: true }));
    const onPause = () => setState((s) => ({ ...s, isPlaying: false }));
    const onWaiting = () => setState((s) => ({ ...s, isLoading: true }));
    const onPlaying = () => setState((s) => ({ ...s, isLoading: false, isPlaying: true }));
    const onEnded = () => setState((s) => ({ ...s, isPlaying: false, position: s.duration }));

    el.addEventListener('timeupdate', onTime);
    el.addEventListener('loadedmetadata', onMeta);
    el.addEventListener('durationchange', onMeta);
    el.addEventListener('play', onPlay);
    el.addEventListener('pause', onPause);
    el.addEventListener('waiting', onWaiting);
    el.addEventListener('playing', onPlaying);
    el.addEventListener('ended', onEnded);
    return () => {
      el.removeEventListener('timeupdate', onTime);
      el.removeEventListener('loadedmetadata', onMeta);
      el.removeEventListener('durationchange', onMeta);
      el.removeEventListener('play', onPlay);
      el.removeEventListener('pause', onPause);
      el.removeEventListener('waiting', onWaiting);
      el.removeEventListener('playing', onPlaying);
      el.removeEventListener('ended', onEnded);
      el.pause();
    };
  }, []);

  const openPage = useCallback((audioUrl: string | null | undefined) => {
    const el = audioRef.current;
    if (!el) return;
    const url = audioUrl && audioUrl.length > 0 ? audioUrl : null;
    if (url === currentUrlRef.current) return; // same page — don't restart
    currentUrlRef.current = url;

    el.pause();
    if (!url) {
      el.removeAttribute('src');
      el.load();
      setState((s) => ({ ...s, hasAudio: false, isPlaying: false, isLoading: false, position: 0, duration: 0 }));
      return;
    }

    el.src = url;
    el.load();
    setState((s) => ({ ...s, hasAudio: true, position: 0, duration: 0, isLoading: true }));
    if (autoplayRef.current) {
      void el.play().catch(() => setState((s) => ({ ...s, isLoading: false })));
    } else {
      setState((s) => ({ ...s, isLoading: false }));
    }
  }, []);

  const togglePlay = useCallback(() => {
    const el = audioRef.current;
    if (!el || !currentUrlRef.current) return;
    if (el.paused) {
      if (el.ended || el.currentTime >= el.duration) el.currentTime = 0;
      void el.play().catch(() => {});
    } else {
      el.pause();
    }
  }, []);

  const replay = useCallback(() => {
    const el = audioRef.current;
    if (!el || !currentUrlRef.current) return;
    el.currentTime = 0;
    void el.play().catch(() => {});
  }, []);

  const seek = useCallback((seconds: number) => {
    const el = audioRef.current;
    if (!el || !currentUrlRef.current) return;
    el.currentTime = seconds;
    setState((s) => ({ ...s, position: seconds }));
  }, []);

  const setAutoplay = useCallback((value: boolean) => {
    autoplayRef.current = value;
    setState((s) => ({ ...s, autoplay: value }));
    if (value) {
      const el = audioRef.current;
      if (el && currentUrlRef.current && el.paused) void el.play().catch(() => {});
    }
  }, []);

  return { ...state, openPage, togglePlay, replay, seek, setAutoplay };
}
