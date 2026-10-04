import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { INTERACTION, SPRING } from './tokens';

const MotionLink = motion.create(Link);

const resolveTag = (as) => {
  if (as === Link || as === 'link') return MotionLink;
  return motion[as] ?? motion.button;
};

/**
 * Adds Apple-like hover / press feedback (subtle scale + spring) to any
 * element: buttons, router links or plain containers.
 *
 *   <Pressable as="link" to="/login" className="btn btn-primary">…</Pressable>
 */
const Pressable = ({ as = 'button', preset = 'button', disabled = false, children, ...rest }) => {
  const Tag = resolveTag(as);
  const { hover, tap } = INTERACTION[preset] ?? INTERACTION.button;

  return (
    <Tag
      whileHover={disabled ? undefined : hover}
      whileTap={disabled ? undefined : tap}
      transition={SPRING.interactive}
      disabled={as === 'button' ? disabled : undefined}
      {...rest}
    >
      {children}
    </Tag>
  );
};

export default Pressable;
