import type { Tables } from './database.types';

/**
 * Domain types for the reader/editor. The DB Row types come straight from the
 * generated `database.types.ts`; here we layer on the shape of the `story.style`
 * JSON blob and a "story with its pages" type for the eager `select('*, page(*)')`.
 * Mirrors the Flutter `StoryStyle` / `Story` / `StoryPage` models.
 */

export type StoryRow = Tables<'story'>;
export type PageRow = Tables<'page'>;

/** Text alignment options stored in `story.style.textAlign`. */
export type TextAlign = 'left' | 'center' | 'right' | 'justify';

/** Curated font-family tokens (matches the Flutter dropdown). */
export type FontFamily = 'Serif' | 'Sans' | 'Mono';

/**
 * Story-wide page styling (the `story.style` jsonb column). Every field is
 * optional; absent fields mean "use reader defaults".
 */
export interface StoryStyle {
  fontFamily?: FontFamily | null;
  fontSizeScale?: number; // 0.8 .. 2.0
  textColor?: string | null; // '#RRGGBB'
  backgroundColor?: string | null; // '#RRGGBB'
  textAlign?: TextAlign | null;
}

/** A story together with its ordered pages (result of `select('*, page(*)')`). */
export type StoryWithPages = StoryRow & { page: PageRow[] };

/** Reader defaults, matching the Flutter reader (black87 text on cream). */
export const READER_DEFAULTS = {
  baseFontPx: 19,
  textColor: 'rgba(0,0,0,0.87)',
  backgroundColor: '#FFF8E7',
  textAlign: 'left' as TextAlign,
  lineHeight: 1.5
};

/** Narrow the untyped jsonb `style` into our {@link StoryStyle} shape. */
export function parseStyle(style: StoryRow['style']): StoryStyle {
  return (style ?? {}) as StoryStyle;
}

/** Map a curated font token to a real CSS font stack (matches the reader). */
export function fontStack(token?: FontFamily | null): string {
  switch (token) {
    case 'Serif':
      return "'Cormorant Garamond', Georgia, serif";
    case 'Mono':
      return "'Courier New', monospace";
    case 'Sans':
    default:
      return "'Quicksand', system-ui, sans-serif";
  }
}

/** Resolve a stored hex (or null) to a usable CSS color, else the fallback. */
export function resolveColor(hex: string | null | undefined, fallback: string): string {
  if (!hex) return fallback;
  return hex;
}

/** Build the inline CSS text style for a story's prose. */
export function proseStyle(style: StoryStyle): string {
  const scale = style.fontSizeScale ?? 1;
  return [
    `font-family:${fontStack(style.fontFamily)}`,
    `font-size:${READER_DEFAULTS.baseFontPx * scale}px`,
    `color:${resolveColor(style.textColor, READER_DEFAULTS.textColor)}`,
    `text-align:${style.textAlign ?? READER_DEFAULTS.textAlign}`,
    `line-height:${READER_DEFAULTS.lineHeight}`
  ].join(';');
}

/* ── Editor helpers ──────────────────────────────────────────────────────── */

/** Preset text/background swatches (null = "use default"). Matches Flutter. */
export const COLOR_SWATCHES: (string | null)[] = [
  null,
  '#000000',
  '#FFFFFF',
  '#5D4037',
  '#B71C1C',
  '#1A237E',
  '#F5EFE0'
];

export const FONT_OPTIONS: { value: FontFamily | null; label: string }[] = [
  { value: null, label: 'Default' },
  { value: 'Serif', label: 'Serif' },
  { value: 'Sans', label: 'Sans' },
  { value: 'Mono', label: 'Mono' }
];

export const ALIGN_OPTIONS: { value: TextAlign; label: string }[] = [
  { value: 'left', label: 'Left' },
  { value: 'center', label: 'Center' },
  { value: 'right', label: 'Right' },
  { value: 'justify', label: 'Justify' }
];

export function hexFromRgb(r: number, g: number, b: number): string {
  const h = (n: number) => n.toString(16).padStart(2, '0').toUpperCase();
  return `#${h(r)}${h(g)}${h(b)}`;
}

export function rgbFromHex(hex: string): { r: number; g: number; b: number } {
  const v = hex.replace('#', '');
  return {
    r: parseInt(v.slice(0, 2), 16) || 0,
    g: parseInt(v.slice(2, 4), 16) || 0,
    b: parseInt(v.slice(4, 6), 16) || 0
  };
}
