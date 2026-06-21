import type { Tables } from '../../lib/database.types';

/**
 * Domain types derived directly from the generated DB types — single source of
 * truth, no drift. `Tables<'story'>` is the exact Row shape from Postgres.
 */
export type StoryRow = Tables<'story'>;
export type PageRow = Tables<'page'>;

/** A story with its ordered pages eager-loaded (the reader's payload). */
export type StoryWithPages = StoryRow & {
  page: PageRow[];
};

/**
 * Story-wide page styling, stored in `story.style` (jsonb). Mirrors the Flutter
 * `StoryStyle` exactly so the column is interoperable between the two clients.
 * The Flutter editor writes `fontFamily` as a token ('Serif' | 'Sans' | 'Mono'),
 * `textColor` / `backgroundColor` as `#RRGGBB` hex, `fontSizeScale` as a 0.8–2.0
 * multiplier on the base prose size. Empty object == "use defaults".
 */
export interface StoryStyle {
  /** Token: 'Serif' | 'Sans' | 'Mono' (undefined = default serif). */
  fontFamily?: string;
  /** Multiplier on the base prose size (0.8–2.0). */
  fontSizeScale?: number;
  /** `#RRGGBB` hex for the page text. */
  textColor?: string;
  /** `#RRGGBB` hex for the solid page background. */
  backgroundColor?: string;
  textAlign?: 'left' | 'center' | 'right' | 'justify';
}

/** Base prose font size, in px, before `fontSizeScale` (matches Flutter's 19.0). */
export const BASE_PROSE_PX = 19;

/** Reader fallbacks when a style field is unset (matches the Flutter reader). */
const DEFAULT_STYLE: Required<StoryStyle> = {
  fontFamily: 'Serif',
  fontSizeScale: 1,
  textColor: '#1a1a1a', // Flutter black87
  backgroundColor: '#fff8e7', // Flutter _cream
  textAlign: 'left',
};

/** Resolve the loose `Json` style blob into a fully-populated style. */
export function resolveStyle(style: unknown): Required<StoryStyle> {
  const s = (style ?? {}) as StoryStyle;
  return {
    fontFamily: s.fontFamily ?? DEFAULT_STYLE.fontFamily,
    fontSizeScale: s.fontSizeScale ?? DEFAULT_STYLE.fontSizeScale,
    textColor: s.textColor ?? DEFAULT_STYLE.textColor,
    backgroundColor: s.backgroundColor ?? DEFAULT_STYLE.backgroundColor,
    textAlign: s.textAlign ?? DEFAULT_STYLE.textAlign,
  };
}

/** Map a `fontFamily` token to a concrete CSS font stack (mirrors Flutter's `_resolveFamily`). */
export function fontFamilyCss(token: string | undefined): string {
  switch (token) {
    case 'Sans':
      return "'Quicksand', system-ui, sans-serif";
    case 'Mono':
      return "ui-monospace, 'SF Mono', Menlo, monospace";
    case 'Serif':
    default:
      return "'Cormorant Garamond', Georgia, serif";
  }
}
