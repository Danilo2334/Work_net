import { Routes, Route } from 'react-router-dom';
import { Sidebar } from '../../components/layout/Sidebar';
import { LayoutDashboard, Search, FileText, Heart, Bell } from 'lucide-react';
import { motion } from 'framer-motion';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';

const candidateNav = [
  { icon: <LayoutDashboard size={20} />, label: 'Overview', path: '' },
  { icon: <Search size={20} />, label: 'Find Jobs', path: '/search' },
  { icon: <FileText size={20} />, label: 'Applications', path: '/applications' },
  { icon: <Heart size={20} />, label: 'Favorites', path: '/favorites' },
  { icon: <Bell size={20} />, label: 'Notifications', path: '/notifications' },
];

function Overview() {
  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.02em' }}>Welcome back, Jane.</h1>
          <p style={{ color: 'var(--text-secondary)' }}>Here's what's happening with your job search today.</p>
        </div>
        <Button>Update Profile</Button>
      </div>

      <div className="grid grid-cols-3 gap-6" style={{ marginBottom: '48px' }}>
        <Card>
          <p className="label">Applications</p>
          <p style={{ fontSize: '32px', fontWeight: 700 }}>12</p>
          <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '8px' }}>+2 this week</p>
        </Card>
        <Card>
          <p className="label">Profile Views</p>
          <p style={{ fontSize: '32px', fontWeight: 700 }}>48</p>
          <p style={{ fontSize: '12px', color: '#34c759', marginTop: '8px' }}>+15% vs last week</p>
        </Card>
        <Card>
          <p className="label">Interviews</p>
          <p style={{ fontSize: '32px', fontWeight: 700 }}>3</p>
          <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '8px' }}>Next: Apple on Thursday</p>
        </Card>
      </div>

      <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '20px' }}>Recommended for you</h2>
      <div className="flex-col gap-4">
        {[1, 2, 3].map(i => (
          <Card key={i} hoverable style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
              <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'rgba(0,0,0,0.04)' }} />
              <div>
                <h3 style={{ fontSize: '16px', fontWeight: 600 }}>Senior Product Designer</h3>
                <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>TechCorp • San Francisco, CA (Hybrid)</p>
              </div>
            </div>
            <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
              <span className="badge badge-blue">Match: 95%</span>
              <Button variant="outline" style={{ padding: '6px 12px' }}>Apply</Button>
            </div>
          </Card>
        ))}
      </div>
    </motion.div>
  );
}

export function CandidateDashboard() {
  return (
    <div className="dashboard-layout">
      <Sidebar items={candidateNav} basePath="/dashboard/candidate" />
      <main className="main-content">
        <Routes>
          <Route path="" element={<Overview />} />
          {/* Other routes can be added here */}
          <Route path="*" element={<div>Work in progress...</div>} />
        </Routes>
      </main>
    </div>
  );
}
