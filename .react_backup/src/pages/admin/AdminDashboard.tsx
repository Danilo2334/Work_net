import { Routes, Route } from 'react-router-dom';
import { Sidebar } from '../../components/layout/Sidebar';
import { LayoutDashboard, ShieldCheck, Building, Users } from 'lucide-react';
import { motion } from 'framer-motion';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';

const adminNav = [
  { icon: <LayoutDashboard size={20} />, label: 'Overview', path: '' },
  { icon: <ShieldCheck size={20} />, label: 'Validations', path: '/validations' },
  { icon: <Building size={20} />, label: 'Companies', path: '/companies' },
  { icon: <Users size={20} />, label: 'Users', path: '/users' },
];

function AdminOverview() {
  const pendingValidations = [
    { id: 1, name: 'Stark Industries', type: 'Company', date: 'Oct 1, 2026' },
    { id: 2, name: 'Wayne Enterprises', type: 'Company', date: 'Oct 2, 2026' },
  ];

  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.02em' }}>Admin Center</h1>
          <p style={{ color: 'var(--text-secondary)' }}>System overview and pending actions.</p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-6" style={{ marginBottom: '48px' }}>
        <Card>
          <p className="label">Total Users</p>
          <p style={{ fontSize: '32px', fontWeight: 700 }}>12,450</p>
        </Card>
        <Card>
          <p className="label">Active Companies</p>
          <p style={{ fontSize: '32px', fontWeight: 700 }}>842</p>
        </Card>
        <Card>
          <p className="label">Pending Validations</p>
          <p style={{ fontSize: '32px', fontWeight: 700 }}>24</p>
        </Card>
      </div>

      <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '20px' }}>Pending Validations</h2>
      <Card style={{ padding: 0, overflow: 'hidden' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid var(--border-color)', backgroundColor: 'rgba(0,0,0,0.02)' }}>
              <th style={{ padding: '16px 24px', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)', fontWeight: 600 }}>Entity Name</th>
              <th style={{ padding: '16px 24px', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)', fontWeight: 600 }}>Type</th>
              <th style={{ padding: '16px 24px', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)', fontWeight: 600 }}>Date Submitted</th>
              <th style={{ padding: '16px 24px', fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)', fontWeight: 600, textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {pendingValidations.map(val => (
              <tr key={val.id} style={{ borderBottom: '1px solid var(--border-color)' }}>
                <td style={{ padding: '16px 24px', fontWeight: 500 }}>{val.name}</td>
                <td style={{ padding: '16px 24px' }}>
                  <span className="badge badge-blue">{val.type}</span>
                </td>
                <td style={{ padding: '16px 24px', color: 'var(--text-secondary)' }}>{val.date}</td>
                <td style={{ padding: '16px 24px', textAlign: 'right', display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
                  <Button variant="outline" style={{ padding: '6px 12px' }}>Review</Button>
                  <Button style={{ padding: '6px 12px' }}>Approve</Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </motion.div>
  );
}

export function AdminDashboard() {
  return (
    <div className="dashboard-layout">
      <Sidebar items={adminNav} basePath="/dashboard/admin" />
      <main className="main-content">
        <Routes>
          <Route path="" element={<AdminOverview />} />
          <Route path="*" element={<div>Work in progress...</div>} />
        </Routes>
      </main>
    </div>
  );
}
