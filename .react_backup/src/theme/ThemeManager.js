import { Observable } from '../lib/Observable';
import { SafeStorage } from '../lib/SafeStorage';

export const THEMES = Object.freeze({ LIGHT: 'light', DARK: 'dark' });

/** Must stay in sync with the inline boot script in index.html (prevents a flash on load). */
export const THEME_STORAGE_KEY = 'worknet-theme';

const TRANSITION_CLASS = 'theme-transition';
const TRANSITION_MS = 450;

/**
 * Owns the global color theme:
 * - resolves the initial theme (stored preference → system preference),
 * - applies it to <html data-theme> + `color-scheme`,
 * - persists explicit user choices,
 * - follows the OS setting while the user hasn't chosen explicitly,
 * - enables a short, global color cross-transition only while switching.
 */
export class ThemeManager extends Observable {
  #root;
  #storage;
  #media;
  #theme;
  #transitionTimer = null;

  constructor({ root = document.documentElement, storage = new SafeStorage() } = {}) {
    super();
    this.#root = root;
    this.#storage = storage;
    this.#media = window.matchMedia?.('(prefers-color-scheme: dark)') ?? null;
    this.#theme = this.#storedTheme() ?? this.#systemTheme();
    this.#apply(this.#theme);
    this.#media?.addEventListener?.('change', this.#handleSystemChange);
  }

  /** Current theme. Arrow function so it can be used as a `getSnapshot`. */
  getTheme = () => this.#theme;

  get isDark() {
    return this.#theme === THEMES.DARK;
  }

  setTheme(theme) {
    if (!Object.values(THEMES).includes(theme) || theme === this.#theme) return;
    this.#storage.set(THEME_STORAGE_KEY, theme);
    this.#change(theme);
  }

  toggle = () => {
    this.setTheme(this.isDark ? THEMES.LIGHT : THEMES.DARK);
  };

  destroy() {
    this.#media?.removeEventListener?.('change', this.#handleSystemChange);
    clearTimeout(this.#transitionTimer);
  }

  #storedTheme() {
    const stored = this.#storage.get(THEME_STORAGE_KEY);
    return Object.values(THEMES).includes(stored) ? stored : null;
  }

  #systemTheme() {
    return this.#media?.matches ? THEMES.DARK : THEMES.LIGHT;
  }

  #handleSystemChange = () => {
    // Only follow the OS while the user has not made an explicit choice.
    if (!this.#storedTheme()) this.#change(this.#systemTheme());
  };

  #change(theme) {
    this.#theme = theme;
    this.#withTransition(() => this.#apply(theme));
    this.notify();
  }

  #apply(theme) {
    this.#root.dataset.theme = theme;
    this.#root.style.colorScheme = theme;
  }

  /**
   * Color transitions are enabled only during the switch, so they never
   * interfere with hover/motion transitions the rest of the time.
   */
  #withTransition(applyChange) {
    const reduceMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    if (reduceMotion) {
      applyChange();
      return;
    }
    clearTimeout(this.#transitionTimer);
    this.#root.classList.add(TRANSITION_CLASS);
    applyChange();
    this.#transitionTimer = setTimeout(() => {
      this.#root.classList.remove(TRANSITION_CLASS);
    }, TRANSITION_MS);
  }
}

/** App-wide singleton. */
export const themeManager = new ThemeManager();
