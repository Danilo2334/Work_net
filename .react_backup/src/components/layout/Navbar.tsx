import { Link, useLocation } from 'react-router-dom';
import { Briefcase, User, Search, Bell } from 'lucide-react';
import { motion } from 'framer-motion';

export function Navbar() {
  const location = useLocation();
  const isDashboard = location.pathname.includes('/dashboard');

  return (
    <nav style={{
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '16px 48px',
      backgroundColor: 'rgba(255, 255, 255, 0.8)',
      backdropFilter: 'blur(20px)',
      WebkitBackdropFilter: 'blur(20px)',
      borderBottom: '1px solid var(--border-color)',
      position: 'sticky',
      top: 0,
      zIndex: 100
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '32px' }}>
        <Link to="/" style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)', fontWeight: 600, fontSize: '18px' }}>
          <Briefcase size={24} color="var(--primary-blue)" />
          <span>TalentFlow</span>
        </Link>
        
        {!isDashboard && (
          <div style={{ display: 'flex', gap: '24px', fontSize: '14px', fontWeight: 500 }}>
            <Link to="/search" style={{ color: 'var(--text-secondary)' }}>Find Jobs</Link>
            <Link to="/companies" style={{ color: 'var(--text-secondary)' }}>For Companies</Link>
          </div>
        )}
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
        {isDashboard ? (
          <>
            <motion.button whileHover={{ scale: 1.1 }} style={{ padding: '8px' }}>
              <Search size={20} color="var(--text-secondary)" />
            </motion.button>
            <motion.button whileHover={{ scale: 1.1 }} style={{ padding: '8px' }}>
              <Bell size={20} color="var(--text-secondary)" />
            </motion.button>
            <div style={{ width: '32px', height: '32px', borderRadius: '50%', backgroundColor: 'var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <User size={16} color="var(--text-secondary)" />
            </div>
          </>
        ) : (
          <>
            <Link to="/login" style={{ fontSize: '14px', fontWeight: 500, color: 'var(--text-primary)' }}>Log In</Link>
            <Link to="/login" className="btn btn-primary" style={{ padding: '8px 16px' }}>Sign Up</Link>
          </>
        )}
      </div>
    </nav>
  );
}
