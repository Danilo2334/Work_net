import { Link, useLocation } from 'react-router-dom';
import { Briefcase } from 'lucide-react';
import { motion } from 'framer-motion';

export interface SidebarItem {
  icon: React.ReactNode;
  label: string;
  path: string;
}

interface SidebarProps {
  items: SidebarItem[];
  basePath: string;
}

export function Sidebar({ items, basePath }: SidebarProps) {
  const location = useLocation();

  return (
    <div className="sidebar">
      <Link to="/" style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)', fontWeight: 600, fontSize: '18px', padding: '0 16px' }}>
        <Briefcase size={24} color="var(--primary-blue)" />
        <span>TalentFlow</span>
      </Link>

      <nav className="sidebar-nav">
        {items.map((item) => {
          const fullPath = `${basePath}${item.path}`;
          const isActive = location.pathname === fullPath || (item.path !== '' && location.pathname.startsWith(fullPath));
          
          return (
            <Link key={item.path} to={fullPath} className={`nav-item ${isActive ? 'active' : ''}`} style={{ position: 'relative' }}>
              {isActive && (
                <motion.div
                  layoutId="sidebar-active"
                  style={{ position: 'absolute', inset: 0, backgroundColor: 'rgba(0, 102, 204, 0.1)', borderRadius: 'var(--radius-sm)', zIndex: 0 }}
                  transition={{ type: "spring", stiffness: 400, damping: 30 }}
                />
              )}
              <span style={{ position: 'relative', zIndex: 1, display: 'flex', alignItems: 'center', gap: '12px' }}>
                {item.icon}
                {item.label}
              </span>
            </Link>
          );
        })}
      </nav>
      
      <div style={{ marginTop: 'auto', padding: '16px', borderTop: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', gap: '12px' }}>
        <div style={{ width: '36px', height: '36px', borderRadius: '50%', backgroundColor: '#e5e5ea', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 600, color: 'var(--text-secondary)' }}>
          J
        </div>
        <div>
          <p style={{ fontSize: '14px', fontWeight: 600 }}>Jane Doe</p>
          <Link to="/login" style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Log out</Link>
        </div>
      </div>
    </div>
  );
}
