import { Routes, Route } from 'react-router-dom';
import { Sidebar } from '../../components/layout/Sidebar';
import { LayoutDashboard, Users, PlusCircle, Settings } from 'lucide-react';
import { motion } from 'framer-motion';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';

const companyNav = [
  { icon: <LayoutDashboard size={20} />, label: 'Overview', path: '' },
  { icon: <Users size={20} />, label: 'Candidates', path: '/candidates' },
  { icon: <PlusCircle size={20} />, label: 'Post a Job', path: '/post-job' },
  { icon: <Settings size={20} />, label: 'Settings', path: '/settings' },
];

function KanbanBoard() {
  const columns = ['Applied', 'Screening', 'Interview', 'Offer', 'Hired'];
  const candidates = [
    { id: 1, name: 'Alice Smith', role: 'Frontend Engineer', stage: 'Applied' },
    { id: 2, name: 'Bob Johnson', role: 'Product Designer', stage: 'Screening' },
    { id: 3, name: 'Charlie Davis', role: 'Backend Engineer', stage: 'Interview' },
  ];

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.02em' }}>Pipeline</h1>
          <p style={{ color: 'var(--text-secondary)' }}>Manage your active candidates.</p>
        </div>
        <Button>Export</Button>
      </div>

      <div style={{ display: 'flex', gap: '20px', overflowX: 'auto', paddingBottom: '20px', minHeight: '600px' }}>
        {columns.map(col => (
          <div key={col} style={{ flex: '0 0 300px', backgroundColor: 'rgba(0,0,0,0.02)', borderRadius: 'var(--radius-md)', padding: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '16px', alignItems: 'center' }}>
              <h3 style={{ fontSize: '14px', fontWeight: 600 }}>{col}</h3>
              <span className="badge badge-gray">{candidates.filter(c => c.stage === col).length}</span>
            </div>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              {candidates.filter(c => c.stage === col).map(candidate => (
                <motion.div key={candidate.id} layoutId={`candidate-${candidate.id}`}>
                  <Card hoverable style={{ padding: '16px', cursor: 'grab' }}>
                    <div style={{ display: 'flex', gap: '12px', alignItems: 'center', marginBottom: '12px' }}>
                      <div style={{ width: '32px', height: '32px', borderRadius: '50%', backgroundColor: 'var(--primary-blue)', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px', fontWeight: 600 }}>
                        {candidate.name.charAt(0)}
                      </div>
                      <div>
                        <p style={{ fontSize: '14px', fontWeight: 600 }}>{candidate.name}</p>
                        <p style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{candidate.role}</p>
                      </div>
                    </div>
                  </Card>
                </motion.div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </motion.div>
  );
}

export function CompanyDashboard() {
  return (
    <div className="dashboard-layout">
      <Sidebar items={companyNav} basePath="/dashboard/company" />
      <main className="main-content" style={{ maxWidth: '100%' }}>
        <Routes>
          <Route path="" element={<KanbanBoard />} />
          <Route path="*" element={<div>Work in progress...</div>} />
        </Routes>
      </main>
    </div>
  );
}
