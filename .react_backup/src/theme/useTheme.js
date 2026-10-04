import { useSyncExternalStore } from 'react';
import { themeManager, THEMES } from './ThemeManager';

/**
 * React binding for the global ThemeManager.
 * No provider is needed: the manager is a singleton external store.
 */
export function useTheme() {
  const theme = useSyncExternalStore(themeManager.subscribe, themeManager.getTheme);

  return {
    theme,
    isDark: theme === THEMES.DARK,
    toggleTheme: themeManager.toggle,
    setTheme: (next) => themeManager.setTheme(next),
  };
}
