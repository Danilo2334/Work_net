import { useRef } from 'react';
import { useIsPresent } from 'framer-motion';

/**
 * Returns `value` while the component is present, and the last present value
 * while it is animating out. Prevents exiting views from re-rendering with
 * new global state (e.g. a cleared session) mid-transition.
 */
export function usePresentValue(value) {
  const isPresent = useIsPresent();
  const lastValue = useRef(value);
  if (isPresent) lastValue.current = value;
  return { value: isPresent ? value : lastValue.current, isPresent };
}
