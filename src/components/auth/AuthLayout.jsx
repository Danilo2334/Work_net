import { motion } from 'framer-motion';
import BrandLogo from '../common/BrandLogo';
import ThemeToggle from '../common/ThemeToggle';
import { Reveal } from '../../motion/Reveal';
import { DURATION, EASE } from '../../motion/tokens';
import './AuthLayout.css';

/**
 * Split layout shared by Login and Register:
 * form column on the left, brand statement panel on the right.
 */
const AuthLayout = ({ title, subtitle, panelTitle, panelText, children, footer }) => (
  <div className="auth">
    <div className="auth__main">
      <header className="auth__header">
        <BrandLogo />
        <ThemeToggle />
      </header>

      <div className="auth__body">
        <Reveal>
          <h1 className="auth__title">{title}</h1>
          <p className="auth__subtitle">{subtitle}</p>
          {children}
          {footer && <p className="auth__footer">{footer}</p>}
        </Reveal>
      </div>
    </div>

    <aside className="auth__panel" aria-hidden="true">
      <div className="auth__panel-glow" />
      <motion.div
        className="auth__panel-content"
        initial={{ opacity: 0, x: 20 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: DURATION.slow * 1.6, delay: 0.2, ease: EASE.out }}
      >
        <h2 className="auth__panel-title">{panelTitle}</h2>
        <p className="auth__panel-text">{panelText}</p>
      </motion.div>
    </aside>
  </div>
);

export default AuthLayout;
