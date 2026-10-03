import React from 'react';
import { useLocation } from 'react-router-dom';
import Sidebar from './Sidebar';
import Crossfade from '../motion/Crossfade';

const DashboardLayout = ({ children, role }) => {
  const location = useLocation();

  return (
    <div className="dashboard-layout">
      <Sidebar role={role} />
      <main className="dashboard-content">
        {/* Section changes crossfade in place (outgoing and incoming overlap). */}
        <Crossfade activeKey={location.pathname} fill>
          {children}
        </Crossfade>
      </main>
    </div>
  );
};

export default DashboardLayout;
