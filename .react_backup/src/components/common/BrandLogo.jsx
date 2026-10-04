import { Link } from 'react-router-dom';
import './BrandLogo.css';

/**
 * WorkNet brand mark. Previously duplicated inline in Landing, Login and the
 * Sidebar; centralised here so every screen shares the same identity.
 */
const BrandLogo = ({ to = '/', showName = true, className = '' }) => {
  const content = (
    <>
      <span className="brand-logo__mark" aria-hidden="true">W</span>
      {showName && <span className="brand-logo__name">WorkNet</span>}
    </>
  );

  return to ? (
    <Link to={to} className={`brand-logo ${className}`.trim()} aria-label="WorkNet – inicio">
      {content}
    </Link>
  ) : (
    <span className={`brand-logo ${className}`.trim()}>{content}</span>
  );
};

export default BrandLogo;
