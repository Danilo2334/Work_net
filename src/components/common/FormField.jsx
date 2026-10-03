import { AnimatePresence, motion } from 'framer-motion';
import { DURATION, EASE } from '../../motion/tokens';

/**
 * Label + input + animated validation message.
 * Any extra prop goes straight to the <input>.
 */
const FormField = ({ id, label, error, hint, ...inputProps }) => {
  const messageId = `${id}-message`;
  return (
    <div className="form-group">
      <label className="label-modern" htmlFor={id}>
        {label}
      </label>
      <input
        id={id}
        className="input-modern"
        aria-invalid={error ? 'true' : undefined}
        aria-describedby={error || hint ? messageId : undefined}
        {...inputProps}
      />
      <AnimatePresence initial={false} mode="wait">
        {(error || hint) && (
          <motion.p
            key={error ? 'error' : 'hint'}
            id={messageId}
            className={`form-message ${error ? 'form-message--error' : ''}`}
            initial={{ opacity: 0, y: -4 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -4 }}
            transition={{ duration: DURATION.fast, ease: EASE.standard }}
          >
            {error || hint}
          </motion.p>
        )}
      </AnimatePresence>
    </div>
  );
};

export default FormField;
