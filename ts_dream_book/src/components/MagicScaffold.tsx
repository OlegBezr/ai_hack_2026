import { useEffect, type ReactNode } from 'react';
import { MagicBackground } from './MagicBackground';
import { MusicControls } from '../features/audio/MusicControls';
import { useBackgroundMusic } from '../features/audio/BackgroundMusic';

/**
 * Page chrome shared by every screen — the React analogue of Flutter's
 * `MagicScaffold`: the twilight background, a transparent app bar (title,
 * leading, actions), the body, an optional floating action button, and the
 * floating music controls (hidden in the reader).
 */
export function MagicScaffold({
  title,
  leading,
  actions,
  children,
  fab,
  showMusicControls = true,
}: {
  title?: ReactNode;
  leading?: ReactNode;
  actions?: ReactNode;
  children: ReactNode;
  fab?: ReactNode;
  showMusicControls?: boolean;
}) {
  const music = useBackgroundMusic();

  useEffect(() => {
    if (showMusicControls) music.ensureStarted();
  }, [showMusicControls, music]);

  return (
    <MagicBackground>
      <div className="flex min-h-screen flex-col">
        {(title || leading || actions) && (
          <header className="flex h-16 shrink-0 items-center gap-2 px-3">
            <div className="flex w-24 items-center gap-1">{leading}</div>
            <h1 className="flex-1 truncate text-center font-display text-lg tracking-wide text-gold sm:text-xl">
              {title}
            </h1>
            <div className="flex w-24 items-center justify-end gap-1">{actions}</div>
          </header>
        )}
        <main className="relative flex flex-1 flex-col">{children}</main>
      </div>

      {showMusicControls && (
        <div className="fixed bottom-3 left-3 z-30">
          <MusicControls />
        </div>
      )}
      {fab && <div className="fixed bottom-6 right-6 z-30">{fab}</div>}
    </MagicBackground>
  );
}
