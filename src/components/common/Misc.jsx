import './Misc.css';

/** Initials avatar (until profile photos exist). */
export const Avatar = ({ name = '', size = 40, className = '' }) => {
  const initials = name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join('');

  return (
    <span
      className={`avatar ${className}`.trim()}
      style={{ width: size, height: size, fontSize: Math.round(size * 0.38) }}
      aria-hidden="true"
    >
      {initials || '?'}
    </span>
  );
};

/** Thin animated progress bar (value 0–100). */
export const ProgressBar = ({ value, label }) => (
  <div
    className="progress"
    role="progressbar"
    aria-valuenow={value}
    aria-valuemin={0}
    aria-valuemax={100}
    aria-label={label}
  >
    <span className="progress__fill" style={{ '--progress': `${value}%` }} />
  </div>
);

/** Placeholder for sections without data yet. */
export const EmptyState = ({ icon: Icon, title, description, action }) => (
  <div className="empty-state">
    {Icon && (
      <span className="empty-state__icon">
        <Icon size={24} />
      </span>
    )}
    <h3 className="empty-state__title">{title}</h3>
    {description && <p className="empty-state__description">{description}</p>}
    {action}
  </div>
);
