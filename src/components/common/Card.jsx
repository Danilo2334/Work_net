import { motion } from 'framer-motion';
import { INTERACTION, SPRING } from '../../motion/tokens';
import './Card.css';

/**
 * Base surface used across dashboards.
 * - `interactive`: Apple-like lift on hover and soft press on tap.
 * - Accepts any framer-motion prop (variants, initial…), so it can be a
 *   `Stagger` child directly.
 */
const Card = ({ as = 'div', interactive = false, padding = 'md', className = '', children, ...rest }) => {
  const Tag = motion[as] ?? motion.div;
  const interaction = interactive
    ? { whileHover: INTERACTION.card.hover, whileTap: INTERACTION.card.tap, transition: SPRING.interactive }
    : {};

  return (
    <Tag
      className={`ui-card ui-card--pad-${padding} ${interactive ? 'ui-card--interactive' : ''} ${className}`.trim()}
      {...interaction}
      {...rest}
    >
      {children}
    </Tag>
  );
};

export default Card;
