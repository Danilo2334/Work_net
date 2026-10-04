import ShaderCard from './ShaderCard';

/**
 * Key-figure card for dashboards: icon, label, main value, optional hint and
 * an optional slot (`children`) for extras such as a progress bar.
 */
const StatCard = ({ icon: Icon, label, value, hint, accent, seed, children, ...rest }) => (
  <ShaderCard accent={accent} seed={seed} interactive className="stat-card" {...rest}>
    <div className="stat-card__header">
      <span className="stat-card__label">{label}</span>
      {Icon && (
        <span className="stat-card__icon">
          <Icon size={18} strokeWidth={2} />
        </span>
      )}
    </div>
    <div className="stat-card__value">{value}</div>
    {hint && <p className="stat-card__hint">{hint}</p>}
    {children}
  </ShaderCard>
);

export default StatCard;
