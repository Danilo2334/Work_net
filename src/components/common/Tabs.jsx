import { useId, useRef } from 'react';
import { motion } from 'framer-motion';
import { SPRING } from '../../motion/tokens';
import './Tabs.css';

/**
 * Accessible segmented control with a shared-layout sliding indicator.
 * Pair it with <Crossfade activeKey={value}> to animate the panels.
 *
 *   tabs = [{ id: 'overview', label: 'Resumen', icon: LayoutGrid }]
 */
const Tabs = ({ tabs, value, onChange, label = 'Secciones', idPrefix }) => {
  const generatedId = useId();
  const prefix = idPrefix ?? generatedId;
  const listRef = useRef(null);

  const focusTab = (index) => {
    const next = tabs[(index + tabs.length) % tabs.length];
    onChange(next.id);
    listRef.current?.querySelector(`[data-tab="${next.id}"]`)?.focus();
  };

  const handleKeyDown = (event) => {
    const current = tabs.findIndex((tab) => tab.id === value);
    const keyMap = { ArrowRight: current + 1, ArrowLeft: current - 1, Home: 0, End: tabs.length - 1 };
    if (event.key in keyMap) {
      event.preventDefault();
      focusTab(keyMap[event.key]);
    }
  };

  return (
    <div className="tabs" role="tablist" aria-label={label} ref={listRef} onKeyDown={handleKeyDown}>
      {tabs.map(({ id, label: tabLabel, icon: Icon }) => {
        const selected = id === value;
        return (
          <button
            key={id}
            id={`${prefix}-tab-${id}`}
            data-tab={id}
            type="button"
            role="tab"
            aria-selected={selected}
            aria-controls={`${prefix}-panel`}
            tabIndex={selected ? 0 : -1}
            className={`tabs__tab ${selected ? 'is-active' : ''}`}
            onClick={() => onChange(id)}
          >
            {selected && (
              <motion.span layoutId={`${prefix}-indicator`} className="tabs__indicator" transition={SPRING.layout} />
            )}
            <span className="tabs__label">
              {Icon && <Icon size={16} />}
              {tabLabel}
            </span>
          </button>
        );
      })}
    </div>
  );
};

export default Tabs;
