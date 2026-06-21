import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from 'react';

/* ───────────────────────────────────────────────────────────────────────────
   Shared "Twilight Storybook" UI primitives — the React analogues of the
   Flutter theme (app_theme.dart) + magical_widgets.dart. Every screen builds
   from these so the look stays consistent.
   ─────────────────────────────────────────────────────────────────────────── */

function cx(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(Boolean).join(' ');
}

/** Frosted-glass surface with a luminous lilac border (Flutter GlassCard). */
export function GlassCard({
  children,
  className,
  onClick,
  padding = 'p-4',
}: {
  children: ReactNode;
  className?: string;
  onClick?: () => void;
  padding?: string;
}) {
  const interactive = onClick != null;
  return (
    <div
      onClick={onClick}
      role={interactive ? 'button' : undefined}
      tabIndex={interactive ? 0 : undefined}
      onKeyDown={
        interactive
          ? (e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                onClick?.();
              }
            }
          : undefined
      }
      className={cx(
        'glass',
        padding,
        interactive && 'cursor-pointer transition hover:brightness-110 active:scale-[0.99]',
        className,
      )}
      style={{
        backgroundImage:
          'linear-gradient(135deg, rgba(255,255,255,0.10), rgba(255,255,255,0.02))',
        borderColor: 'color-mix(in srgb, var(--color-lilac) 28%, transparent)',
      }}
    >
      {children}
    </div>
  );
}

/** Brand wordmark: glowing icon + engraved Cinzel title (Flutter MagicWordmark). */
export function MagicWordmark({
  text,
  fontSize = 40,
  icon = '✦',
}: {
  text: string;
  fontSize?: number;
  icon?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center">
      <span
        className="text-gold"
        style={{
          fontSize: fontSize * 0.9,
          filter: 'drop-shadow(0 0 14px color-mix(in srgb, var(--color-gold) 70%, transparent))',
        }}
      >
        {icon}
      </span>
      <h1
        className="font-display text-center font-bold text-gold"
        style={{
          fontSize,
          letterSpacing: 2,
          marginTop: fontSize * 0.2,
          textShadow:
            '0 0 24px color-mix(in srgb, var(--color-gold) 55%, transparent), 0 2px 2px rgba(0,0,0,0.66)',
        }}
      >
        {text}
      </h1>
    </div>
  );
}

/** Candle-gold spinner ring (Flutter CircularProgressIndicator(color: gold)). */
export function Spinner({ size = 24, className }: { size?: number; className?: string }) {
  return (
    <span
      className={cx('inline-block animate-spin rounded-full', className)}
      style={{
        width: size,
        height: size,
        border: `${Math.max(2, size / 12)}px solid color-mix(in srgb, var(--color-gold) 30%, transparent)`,
        borderTopColor: 'var(--color-gold)',
      }}
    />
  );
}

type ButtonVariant = 'filled' | 'outlined' | 'text';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  loading?: boolean;
  icon?: ReactNode;
}

/** Themed button. filled=gold CTA, outlined=lilac, text=gold link (app_theme.dart). */
export function Button({
  variant = 'filled',
  loading = false,
  icon,
  children,
  className,
  disabled,
  ...rest
}: ButtonProps) {
  const base =
    'inline-flex items-center justify-center gap-2 font-body font-semibold transition disabled:opacity-50 disabled:cursor-not-allowed';
  const styles: Record<ButtonVariant, string> = {
    filled: 'rounded-2xl px-5 py-3 text-[#2a1b05] bg-gold hover:brightness-105 active:scale-[0.98]',
    outlined:
      'rounded-[14px] px-4 py-2.5 text-lilac border hover:bg-white/5 active:scale-[0.98]',
    text: 'px-2 py-1 text-gold hover:underline',
  };
  return (
    <button
      {...rest}
      disabled={disabled || loading}
      className={cx(base, styles[variant], className)}
      style={
        variant === 'outlined'
          ? { borderColor: 'color-mix(in srgb, var(--color-lilac) 50%, transparent)' }
          : undefined
      }
    >
      {loading ? (
        <Spinner size={18} className={variant === 'filled' ? '!border-[#2a1b05]/30 !border-t-[#2a1b05]' : ''} />
      ) : (
        icon
      )}
      {children}
    </button>
  );
}

/** Circular glassy icon button (used in app bars, page-turn controls). */
export function IconButton({
  children,
  title,
  className,
  glow = false,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { glow?: boolean }) {
  return (
    <button
      {...rest}
      title={title}
      aria-label={title}
      className={cx(
        'inline-flex h-10 w-10 items-center justify-center rounded-full text-gold transition hover:bg-white/10 disabled:opacity-40 disabled:cursor-not-allowed',
        className,
      )}
      style={glow ? { boxShadow: '0 0 18px color-mix(in srgb, var(--color-gold) 35%, transparent)' } : undefined}
    >
      {children}
    </button>
  );
}

/** Labeled text input matching the Flutter InputDecorationTheme (gold focus). */
export function TextField({
  label,
  helper,
  prefix,
  className,
  ...rest
}: Omit<InputHTMLAttributes<HTMLInputElement>, 'prefix'> & {
  label?: string;
  helper?: string;
  prefix?: ReactNode;
}) {
  return (
    <label className="block">
      {label && <span className="mb-1.5 block text-sm font-medium text-ink-muted">{label}</span>}
      <div
        className="flex items-center gap-2 rounded-2xl border bg-white/[0.06] px-3 transition focus-within:border-gold"
        style={{ borderColor: 'color-mix(in srgb, var(--color-lilac) 25%, transparent)' }}
      >
        {prefix && <span className="text-lilac">{prefix}</span>}
        <input
          {...rest}
          className={cx(
            'w-full bg-transparent py-3 text-ink placeholder:text-ink-muted/70 outline-none disabled:opacity-60',
            className,
          )}
        />
      </div>
      {helper && <span className="mt-1 block text-xs text-ink-muted">{helper}</span>}
    </label>
  );
}

/** Multi-line textarea sharing the TextField chrome. */
export function TextArea({
  className,
  ...rest
}: InputHTMLAttributes<HTMLTextAreaElement> & { rows?: number }) {
  return (
    <textarea
      {...rest}
      className={cx(
        'w-full rounded-2xl border bg-white/[0.06] px-3 py-3 text-ink placeholder:text-ink-muted/70 outline-none transition focus:border-gold',
        className,
      )}
      style={{ borderColor: 'color-mix(in srgb, var(--color-lilac) 25%, transparent)' }}
    />
  );
}

/** Uppercase gold section label (Flutter profile `_SectionLabel`). */
export function SectionLabel({ children }: { children: ReactNode }) {
  return (
    <span className="font-body text-xs font-bold uppercase tracking-wider text-gold">{children}</span>
  );
}

/** Gradient gold→amber avatar circle showing the user's initial. */
export function Avatar({ initial, size = 40 }: { initial: string; size?: number }) {
  return (
    <span
      className="inline-flex items-center justify-center rounded-full font-display font-bold text-[#2a1b05]"
      style={{
        width: size,
        height: size,
        fontSize: size * 0.45,
        background: 'radial-gradient(circle at 35% 30%, var(--color-gold), var(--color-amber))',
        boxShadow: '0 0 16px color-mix(in srgb, var(--color-gold) 40%, transparent)',
      }}
    >
      {initial.toUpperCase()}
    </span>
  );
}
