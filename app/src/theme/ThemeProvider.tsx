import React, { createContext, useContext, useMemo } from 'react';
import { Platform, useColorScheme } from 'react-native';
import { dark, light, font, type Palette } from './tokens';

export type ThemeChoice = 'light' | 'dark' | 'auto';

interface Theme {
  c: Palette;
  isDark: boolean;
  mono: string;
}

const ThemeCtx = createContext<Theme>({ c: light, isDark: false, mono: 'Menlo' });

export const useTheme = () => useContext(ThemeCtx);

export function ThemeProvider({
  choice,
  children,
}: {
  choice: ThemeChoice;
  children: React.ReactNode;
}) {
  // `auto` must keep *following* the device rather than reading it once — the OS flips
  // at dusk and the app has to flip with it. useColorScheme re-renders on change.
  const device = useColorScheme();
  const isDark = choice === 'auto' ? device === 'dark' : choice === 'dark';

  const value = useMemo<Theme>(
    () => ({
      c: isDark ? dark : light,
      isDark,
      mono: Platform.OS === 'android' ? font.monoAndroid : font.mono,
    }),
    [isDark],
  );

  return <ThemeCtx.Provider value={value}>{children}</ThemeCtx.Provider>;
}
