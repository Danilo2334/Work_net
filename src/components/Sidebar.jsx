import React from 'react';
import { motion } from 'framer-motion';
import { Link, useLocation } from 'react-router-dom';
import { LogOut } from 'lucide-react';
import { ROLES, WELCOME_NAV_ITEM, getRole } from '../config/roles';
import { useSession } from '../services/useSession';
import { SPRING } from '../motion/tokens';
import BrandLogo from './common/BrandLogo';
import ThemeToggle from './common/ThemeToggle';
import { Avatar } from './common/Misc';
import './Sidebar.css';

const SidebarLink = ({ path, icon: Icon, label, isActive }) => (
  <Link to={path} className={`sidebar__link ${isActive ? 'is-active' : ''}`} aria-current={isActive ? 'page' : undefined}>
    {isActive && <motion.span layoutId="sidebar-active" className="sidebar__link-bg" transition={SPRING.layout} />}
    <span className="sidebar__link-content">
      <Icon size={20} />
      <span className="sidebar__link-label">{label}</span>
    </span>
  </Link>
);

const Sidebar = ({ role }) => {
  const location = useLocation();
  const { user, logout } = useSession();

  // Registered users of this role also get their welcome dashboard as "Inicio".
  const ownsRole = user?.role === role;
  const links = [...(ownsRole ? [WELCOME_NAV_ITEM] : []), ...(ROLES[role]?.nav ?? [])];

  return (
    <aside className="dashboard-sidebar">
      <div className="sidebar__brand">
        <BrandLogo />
      </div>

      <nav className="sidebar__nav" aria-label="Navegación principal">
        {links.map((link) => (
          <SidebarLink key={link.path} {...link} isActive={location.pathname === link.path} />
        ))}
      </nav>

      <div className="sidebar__footer">
        {ownsRole && (
          <div className="sidebar__user">
            <Avatar name={user.name} size={36} />
            <div className="sidebar__user-info">
              <span className="sidebar__user-name">{user.name}</span>
              <span className="sidebar__user-role">{getRole(user.role)?.label}</span>
            </div>
          </div>
        )}
        <div className="sidebar__actions">
          <Link to="/" className="sidebar__link sidebar__logout" onClick={logout}>
            <span className="sidebar__link-content">
              <LogOut size={20} />
              <span className="sidebar__link-label">Cerrar Sesión</span>
            </span>
          </Link>
          <ThemeToggle />
        </div>
      </div>
    </aside>
  );
};

export default Sidebar;
