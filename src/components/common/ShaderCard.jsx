import Card from './Card';
import ShaderBackground from './ShaderBackground';

/**
 * Card with the decorative shader layer behind its content.
 * `accent` selects a palette defined in CSS (blue | violet | teal | green).
 */
const ShaderCard = ({ accent = 'blue', seed, className = '', children, ...rest }) => (
  <Card className={`ui-card--shader ui-card--accent-${accent} ${className}`.trim()} {...rest}>
    <ShaderBackground seed={seed} />
    <div className="ui-card__content">{children}</div>
  </Card>
);

export default ShaderCard;
