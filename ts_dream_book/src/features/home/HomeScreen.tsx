import { useNavigate } from 'react-router-dom';
import { MagicScaffold } from '../../components/MagicScaffold';
import { GlassCard, MagicWordmark } from '../../components/ui';
import { useAuth } from '../auth/AuthProvider';

/**
 * Enchanted landing page — the React port of `home_page.dart`. The hero portal
 * leads into the user's library (the router sends them to login first if they
 * are not signed in). Three glass cards tease what the app does.
 */
export function HomeScreen() {
  const navigate = useNavigate();
  const { session } = useAuth();

  const features = [
    { icon: '✍️', title: 'Write', subtitle: 'Pen your tale, page by page.' },
    { icon: '🎨', title: 'Illustrate', subtitle: 'Conjure art for every scene.' },
    { icon: '🔊', title: 'Narrate', subtitle: 'Give your story a voice.' },
  ];

  return (
    <MagicScaffold>
      <div className="mx-auto flex min-h-full max-w-xl flex-col px-5 pb-10 pt-9">
        <div className="pt-3">
          <MagicWordmark text="Dream Book" fontSize={42} />
        </div>
        <p className="mt-3 text-center font-serif text-lg italic text-ink-muted">
          Where your stories come to life
        </p>

        {/* Hero portal into the library */}
        <div className="mt-8">
          <GlassCard onClick={() => navigate('/stories')} padding="p-5">
            <div className="flex items-center gap-4">
              <span
                className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full text-2xl text-[#2a1b05]"
                style={{
                  background: 'radial-gradient(circle at 35% 30%, var(--color-gold), var(--color-amber))',
                  boxShadow: '0 0 20px color-mix(in srgb, var(--color-gold) 50%, transparent)',
                }}
              >
                📖
              </span>
              <div className="flex-1">
                <h2 className="font-display text-xl text-ink">My Stories</h2>
                <p className="mt-1 text-sm text-ink-muted">
                  {session ? 'Open your library and keep weaving.' : 'Sign in to weave and edit your tales.'}
                </p>
              </div>
              <span className="text-gold">›</span>
            </div>
          </GlassCard>
        </div>

        {/* Divider */}
        <div className="mt-7 flex items-center gap-3">
          <span className="h-px flex-1 bg-gradient-to-r from-transparent via-lilac/50 to-transparent" />
          <span className="font-display tracking-wide text-ink-muted">Pick a spell</span>
          <span className="h-px flex-1 bg-gradient-to-r from-transparent via-lilac/50 to-transparent" />
        </div>

        <div className="mt-4 flex flex-col gap-3.5">
          {features.map((f) => (
            <GlassCard key={f.title} padding="p-4">
              <div className="flex items-center gap-3.5">
                <span
                  className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full text-xl"
                  style={{
                    background: 'color-mix(in srgb, var(--color-lilac) 16%, transparent)',
                    border: '1px solid color-mix(in srgb, var(--color-lilac) 40%, transparent)',
                  }}
                >
                  {f.icon}
                </span>
                <div className="flex-1">
                  <h3 className="font-body font-bold text-ink">{f.title}</h3>
                  <p className="text-[13px] text-ink-muted">{f.subtitle}</p>
                </div>
              </div>
            </GlassCard>
          ))}
        </div>
      </div>
    </MagicScaffold>
  );
}
