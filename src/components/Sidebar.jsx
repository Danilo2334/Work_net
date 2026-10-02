import React from 'react';
import { motion } from 'framer-motion';
import { Link, useLocation } from 'react-router-dom';
import { Briefcase, LayoutDashboard, Users, FileText, Settings, LogOut, CheckCircle } from 'lucide-react';

const Sidebar = ({ role }) => {
  const location = useLocation();

  const navItems = {
    candidate: [
      { path: '/candidate', icon: <LayoutDashboard size={20} />, label: 'Dashboard' },
      { path: '/candidate/jobs', icon: <Briefcase size={20} />, label: 'Búsqueda de Ofertas' },
      { path: '/candidate/applications', icon: <FileText size={20} />, label: 'Postulaciones' },
      { path: '/candidate/profile', icon: <Users size={20} />, label: 'Perfil y CV' },
    ],
    company: [
      { path: '/company', icon: <LayoutDashboard size={20} />, label: 'Dashboard' },
      { path: '/company/jobs', icon: <Briefcase size={20} />, label: 'Mis Ofertas' },
      { path: '/company/candidates', icon: <Users size={20} />, label: 'Candidatos' },
    ],
    admin: [
      { path: '/admin', icon: <LayoutDashboard size={20} />, label: 'Dashboard' },
      { path: '/admin/companies', icon: <CheckCircle size={20} />, label: 'Validar Empresas' },
      { path: '/admin/users', icon: <Users size={20} />, label: 'Usuarios' },
    ],
  };

  const links = navItems[role] || [];

  return (
    <div className="dashboard-sidebar">
      <div className="flex items-center gap-2 mb-8 px-4 mt-4">
        <div className="w-8 h-8 rounded-lg bg-blue-600 flex items-center justify-center text-white font-bold" style={{ backgroundColor: '#0066cc' }}>
          W
        </div>
        <span className="font-bold text-xl tracking-tight">WorkNet</span>
      </div>

      <nav className="flex flex-col gap-2 flex-1">
        {links.map((link) => {
          const isActive = location.pathname === link.path;
          return (
            <Link
              key={link.path}
              to={link.path}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '12px',
                padding: '12px 16px',
                borderRadius: '12px',
                color: isActive ? '#0066cc' : '#86868b',
                backgroundColor: isActive ? 'rgba(0, 102, 204, 0.1)' : 'transparent',
                fontWeight: isActive ? '600' : '500',
                textDecoration: 'none',
                transition: 'all 0.2s ease',
              }}
              className="hover-lift"
            >
              {link.icon}
              <span>{link.label}</span>
              {isActive && (
                <motion.div
                  layoutId="sidebar-active"
                  style={{
                    position: 'absolute',
                    left: 0,
                    width: '4px',
                    height: '24px',
                    backgroundColor: '#0066cc',
                    borderTopRightRadius: '4px',
                    borderBottomRightRadius: '4px',
                  }}
                  initial={false}
                  transition={{ type: 'spring', stiffness: 300, damping: 30 }}
                />
              )}
            </Link>
          );
        })}
      </nav>

      <div className="mt-auto">
        <Link
          to="/"
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            padding: '12px 16px',
            borderRadius: '12px',
            color: '#86868b',
            textDecoration: 'none',
            fontWeight: '500',
            transition: 'all 0.2s ease',
          }}
          className="hover-lift"
        >
          <LogOut size={20} />
          <span>Cerrar Sesión</span>
        </Link>
      </div>
    </div>
  );
};

export default Sidebar;
