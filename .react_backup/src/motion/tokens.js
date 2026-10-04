/**
 * Motion design tokens.
 * Every animation in the app should pull its timing from here so the whole
 * interface moves with the same "voice": quick, soft and never exaggerated.
 */

export const EASE = Object.freeze({
  /** Apple's default UI curve – general purpose state changes. */
  standard: [0.25, 0.1, 0.25, 1],
  /** Decelerating curve for elements entering the screen. */
  out: [0.22, 1, 0.36, 1],
  /** Accelerating curve for elements leaving the screen. */
  in: [0.4, 0, 1, 1],
});

export const DURATION = Object.freeze({
  fast: 0.18,
  base: 0.28,
  slow: 0.5,
});

export const SPRING = Object.freeze({
  /** Hover / press feedback: responsive, no visible overshoot. */
  interactive: { type: 'spring', stiffness: 400, damping: 30, mass: 0.8 },
  /** Shared-layout indicators (tabs, nav pills). */
  layout: { type: 'spring', stiffness: 380, damping: 34 },
});

/** Distances are intentionally tiny – motion should be felt, not noticed. */
export const DISTANCE = Object.freeze({ enter: 12, exit: 6 });

export const STAGGER = 0.06;

export const fadeUp = Object.freeze({
  hidden: { opacity: 0, y: DISTANCE.enter },
  visible: { opacity: 1, y: 0, transition: { duration: DURATION.slow, ease: EASE.out } },
  exit: { opacity: 0, y: -DISTANCE.exit, transition: { duration: DURATION.fast, ease: EASE.in } },
});

export const crossfade = Object.freeze({
  initial: { opacity: 0 },
  animate: { opacity: 1, transition: { duration: DURATION.base, ease: EASE.standard } },
  exit: { opacity: 0, transition: { duration: DURATION.base, ease: EASE.standard } },
});

/** Micro-interaction presets for cards and buttons. */
export const INTERACTION = Object.freeze({
  card: { hover: { y: -3, scale: 1.005 }, tap: { scale: 0.99 } },
  button: { hover: { scale: 1.02 }, tap: { scale: 0.97 } },
  icon: { hover: { scale: 1.06 }, tap: { scale: 0.92 } },
});
