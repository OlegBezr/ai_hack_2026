import { useState } from 'react';
import { TRACKS, useBackgroundMusic } from './BackgroundMusic';

/**
 * Floating background-music controls (Flutter `MusicControls`): a glassy pill
 * with a mute toggle and a settings button that opens a track picker.
 */
export function MusicControls() {
  const music = useBackgroundMusic();
  const [open, setOpen] = useState(false);

  return (
    <div className="relative">
      {open && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
          <div
            className="glass absolute bottom-14 left-0 z-20 w-56 overflow-hidden rounded-2xl p-2"
            style={{ background: 'color-mix(in srgb, var(--color-night-mid) 95%, transparent)' }}
          >
            <p className="px-2 py-1.5 font-display text-base text-ink">Background music</p>
            {TRACKS.map((track, i) => {
              const selected = i === music.trackIndex;
              return (
                <button
                  key={track.src}
                  type="button"
                  onClick={() => {
                    music.selectTrack(i);
                    setOpen(false);
                  }}
                  className="flex w-full items-center gap-2 rounded-lg px-2 py-2 text-left text-sm hover:bg-white/5"
                >
                  <span className={selected ? 'text-gold' : 'text-lilac'}>
                    {selected ? '♪' : '♬'}
                  </span>
                  <span className={selected ? 'flex-1 font-semibold text-gold' : 'flex-1 text-ink'}>
                    {track.label}
                  </span>
                  {selected && <span className="text-gold">✓</span>}
                </button>
              );
            })}
          </div>
        </>
      )}

      <div
        className="flex items-center gap-1 rounded-3xl border px-1.5 py-1"
        style={{
          background: 'color-mix(in srgb, black 28%, transparent)',
          borderColor: 'color-mix(in srgb, var(--color-lilac) 25%, transparent)',
        }}
      >
        <button
          type="button"
          title={music.muted ? 'Unmute music' : 'Mute music'}
          aria-label={music.muted ? 'Unmute music' : 'Mute music'}
          onClick={music.toggleMute}
          className="flex h-9 w-9 items-center justify-center rounded-full text-gold hover:bg-white/10"
        >
          {music.muted ? '🔇' : '🔊'}
        </button>
        <button
          type="button"
          title="Music settings"
          aria-label="Music settings"
          onClick={() => setOpen((o) => !o)}
          className="flex h-9 w-9 items-center justify-center rounded-full text-gold hover:bg-white/10"
        >
          ⚙
        </button>
      </div>
    </div>
  );
}
