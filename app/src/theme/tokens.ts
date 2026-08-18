/**
 * The palette from design/prototype.html, as typed tokens.
 *
 * Neutrals are biased green so they read as chosen rather than inherited, and tie to the
 * accent. One accent — a deep chart-ink teal — reserved for *measured* state. Amber is
 * semantic only: the estimating state and the safety floor, never decoration.
 */

export interface Palette {
  ground: string;
  surface: string;
  sunken: string;
  ink: string;
  ink2: string;
  ink3: string;
  line: string;
  accent: string;
  accentSoft: string;
  warn: string;
  warnSoft: string;
  onAccent: string;
  scrim: string;
}

export const light: Palette = {
  ground: '#F6F8F7',
  surface: '#FFFFFF',
  sunken: '#F0F3F2',
  ink: '#141C1A',
  ink2: '#5C6B66',
  ink3: '#8B9A94',
  line: '#E1E7E4',
  accent: '#0E6B5B',
  accentSoft: '#E4F0EC',
  warn: '#9A5B0C',
  warnSoft: '#F7EFE1',
  onAccent: '#FFFFFF',
  scrim: 'rgba(6,14,12,0.34)',
};

export const dark: Palette = {
  ground: '#0E1513',
  surface: '#151E1B',
  sunken: '#111917',
  ink: '#E9EFEC',
  ink2: '#9DACA7',
  ink3: '#6E7D78',
  line: '#24302C',
  accent: '#46C0A4',
  accentSoft: '#17322B',
  warn: '#D69A4E',
  warnSoft: '#2C2317',
  onAccent: '#08110F',
  scrim: 'rgba(0,0,0,0.5)',
};

/**
 * Every number is mono, every word is sans — instruments label in sans and read out in
 * mono. Platform faces, so nothing can silently fall back to a substitute.
 */
export const font = {
  sans: undefined as string | undefined, // system default
  mono: 'Menlo',
  monoAndroid: 'monospace',
} as const;

export const radius = { card: 14, pill: 999, sheet: 20, control: 10 } as const;
export const space = (n: number) => n * 4;
