import { AnimatePresence, motion } from 'framer-motion';
import { crossfade } from './tokens';
import './motion.css';

/**
 * True crossfade between views: outgoing and incoming layers overlap in the
 * same grid cell (no absolute positioning, no layout jump) while their
 * opacities swap. Change `activeKey` to transition.
 */
const Crossfade = ({ activeKey, children, className = '', initial = true, fill = false }) => (
  <div className={`crossfade ${fill ? 'crossfade--fill' : ''} ${className}`.trim()}>
    <AnimatePresence initial={initial}>
      <motion.div
        key={activeKey}
        className="crossfade__layer"
        variants={crossfade}
        initial="initial"
        animate="animate"
        exit="exit"
      >
        {children}
      </motion.div>
    </AnimatePresence>
  </div>
);

export default Crossfade;
