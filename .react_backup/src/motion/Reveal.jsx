import { motion } from 'framer-motion';
import { fadeUp, STAGGER } from './tokens';

const getMotionTag = (as) => motion[as] ?? motion.div;

const withDelay = (delay) =>
  delay
    ? { ...fadeUp, visible: { ...fadeUp.visible, transition: { ...fadeUp.visible.transition, delay } } }
    : fadeUp;

/**
 * Soft fade + lift on enter. With `inView`, it plays when scrolled into view.
 */
export const Reveal = ({ as = 'div', delay = 0, inView = false, children, ...rest }) => {
  const Tag = getMotionTag(as);
  const trigger = inView
    ? { whileInView: 'visible', viewport: { once: true, margin: '0px 0px -10% 0px' } }
    : { animate: 'visible' };

  return (
    <Tag
      variants={withDelay(delay)}
      initial="hidden"
      exit="exit"
      {...trigger}
      {...rest}
    >
      {children}
    </Tag>
  );
};

/**
 * Orchestrates its `StaggerItem` children so they enter one after another.
 */
export const Stagger = ({ as = 'div', delay = 0, step = STAGGER, children, ...rest }) => {
  const Tag = getMotionTag(as);
  return (
    <Tag
      initial="hidden"
      animate="visible"
      exit="exit"
      variants={{
        hidden: {},
        visible: { transition: { staggerChildren: step, delayChildren: delay } },
        exit: {},
      }}
      {...rest}
    >
      {children}
    </Tag>
  );
};

/** Child of `Stagger`; inherits the orchestrated variant states. */
export const StaggerItem = ({ as = 'div', children, ...rest }) => {
  const Tag = getMotionTag(as);
  return (
    <Tag variants={fadeUp} {...rest}>
      {children}
    </Tag>
  );
};
