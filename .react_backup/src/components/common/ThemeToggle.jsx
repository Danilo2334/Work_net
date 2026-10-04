import { AnimatePresence, motion } from 'framer-motion';
import { Moon, Sun } from 'lucide-react';
import { useTheme } from '../../theme/useTheme';
import { DURATION, EASE, INTERACTION, SPRING } from '../../motion/tokens';
import './ThemeToggle.css';

const iconMotion = {
  initial: { opacity: 0, rotate: -90, scale: 0.6 },
  animate: { opacity: 1, rotate: 0, scale: 1, transition: { duration: DURATION.base, ease: EASE.out } },
  exit: { opacity: 0, rotate: 90, scale: 0.6, transition: { duration: DURATION.fast, ease: EASE.in } },
};

/** Global light / dark switch. */
const ThemeToggle = ({ id = 'theme-toggle', className = '' }) => {
  const { isDark, toggleTheme } = useTheme();
  const label = isDark ? 'Activar modo claro' : 'Activar modo oscuro';

  return (
    <motion.button
      type="button"
      id={id}
      className={`theme-toggle ${className}`.trim()}
      onClick={toggleTheme}
      aria-label={label}
      title={label}
      whileHover={INTERACTION.icon.hover}
      whileTap={INTERACTION.icon.tap}
      transition={SPRING.interactive}
    >
      <AnimatePresence mode="popLayout" initial={false}>
        <motion.span key={isDark ? 'moon' : 'sun'} className="theme-toggle__icon" {...iconMotion}>
          {isDark ? <Moon size={17} /> : <Sun size={17} />}
        </motion.span>
      </AnimatePresence>
    </motion.button>
  );
};

export default ThemeToggle;
