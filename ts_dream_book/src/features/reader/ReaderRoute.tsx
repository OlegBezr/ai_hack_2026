import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { MagicBackground } from '../../components/MagicBackground';
import { getStoryWithPages } from '../stories/repository';
import { findSampleStory } from '../stories/sample';
import type { StoryWithPages } from '../stories/types';
import { ReaderScreen } from './ReaderScreen';

type LoadState =
  | { kind: 'loading' }
  | { kind: 'ready'; story: StoryWithPages }
  | { kind: 'missing' };

/** Resolves the :id param — local sample first, then the typed Supabase query. */
export function ReaderRoute() {
  const { id = '' } = useParams();
  const [state, setState] = useState<LoadState>({ kind: 'loading' });

  useEffect(() => {
    let cancelled = false;

    const sample = findSampleStory(id);
    if (sample) {
      setState({ kind: 'ready', story: sample });
      return;
    }

    setState({ kind: 'loading' });
    getStoryWithPages(id)
      .then((story) => {
        if (cancelled) return;
        setState(story ? { kind: 'ready', story } : { kind: 'missing' });
      })
      .catch(() => !cancelled && setState({ kind: 'missing' }));

    return () => {
      cancelled = true;
    };
  }, [id]);

  if (state.kind === 'ready') return <ReaderScreen story={state.story} />;

  return (
    <MagicBackground>
      <div className="flex min-h-screen flex-col items-center justify-center gap-4">
        <p className="font-serif text-xl italic text-ink-muted">
          {state.kind === 'loading' ? 'Opening the book…' : 'This story could not be found.'}
        </p>
        {state.kind === 'missing' && (
          <Link to="/" className="text-sm text-gold hover:underline">
            ‹ Back to library
          </Link>
        )}
      </div>
    </MagicBackground>
  );
}
