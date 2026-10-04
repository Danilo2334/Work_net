import React, { useState } from 'react';
import { Plus, MoreVertical, LayoutGrid, List } from 'lucide-react';
import DashboardLayout from '../components/DashboardLayout';
import { Reveal, Stagger } from '../motion/Reveal';
import Card from '../components/common/Card';
import Pressable from '../motion/Pressable';
import { Avatar } from '../components/common/Misc';
import { motion } from 'framer-motion';
import Tabs from '../components/common/Tabs';
import { Crossfade } from '../motion';

const CompanyDashboard = () => {
  const [activeTab, setActiveTab] = useState('kanban');

  const columns = [
    { id: 'new', title: 'Nuevos', count: 3 },
    { id: 'review', title: 'En Revisión', count: 2 },
    { id: 'interview', title: 'Entrevistas', count: 1 },
    { id: 'offer', title: 'Oferta', count: 0 },
  ];

  const candidates = [
    { id: 1, name: 'Alex Johnson', role: 'Frontend Dev', status: 'new', date: '2023-10-25' },
    { id: 2, name: 'Sarah Miller', role: 'UX Designer', status: 'new', date: '2023-10-24' },
    { id: 3, name: 'Michael Chen', role: 'Fullstack', status: 'new', date: '2023-10-23' },
    { id: 4, name: 'Emma Davis', role: 'Product Manager', status: 'review', date: '2023-10-22' },
    { id: 5, name: 'James Wilson', role: 'Backend Dev', status: 'review', date: '2023-10-20' },
    { id: 6, name: 'Olivia Taylor', role: 'Frontend Dev', status: 'interview', date: '2023-10-18' },
  ];

  const tabs = [
    { id: 'kanban', label: 'Tablero', icon: LayoutGrid },
    { id: 'list', label: 'Lista', icon: List },
  ];

  return (
    <DashboardLayout role="company">
      <div style={{ maxWidth: '1200px', margin: '0 auto', padding: '32px', height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Reveal>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '16px' }}>
            <div>
              <h1 style={{ fontSize: '32px', fontWeight: 700, margin: '0 0 8px' }}>Gestión de Candidatos</h1>
              <p style={{ color: 'var(--text-secondary)', fontSize: '16px', margin: 0 }}>Rol activo: Senior Frontend Developer</p>
            </div>
            <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
              <Tabs tabs={tabs} value={activeTab} onChange={setActiveTab} />
              <Pressable className="btn btn-primary" style={{ borderRadius: '980px', padding: '10px 20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Plus size={20} /> Nueva Oferta
              </Pressable>
            </div>
          </div>
        </Reveal>

        <Crossfade activeKey={activeTab} fill>
          {activeTab === 'kanban' && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '24px', flex: 1, alignItems: 'flex-start' }}>
              {columns.map((column, colIndex) => (
                <Reveal key={column.id} delay={colIndex * 0.1} style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
                  <div style={{ backgroundColor: 'var(--surface-color)', padding: '24px', borderRadius: '16px', border: '1px solid var(--border-color)', height: '100%', display: 'flex', flexDirection: 'column' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                      <h3 style={{ fontSize: '16px', fontWeight: 600 }}>{column.title}</h3>
                      <span style={{ backgroundColor: 'var(--bg-color)', color: 'var(--text-primary)', padding: '4px 12px', borderRadius: '12px', fontSize: '12px', fontWeight: 600, border: '1px solid var(--border-color)' }}>
                        {column.count}
                      </span>
                    </div>
                    
                    <Stagger staggerChildren={0.05} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                      {candidates.filter(c => c.status === column.id).map((candidate) => (
                        <motion.div layoutId={`candidate-${candidate.id}`} key={candidate.id}>
                          <Card hoverable className="glass-panel" style={{ padding: '16px', cursor: 'grab' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                              <div style={{ display: 'flex', gap: '12px' }}>
                                <Avatar name={candidate.name} size={40} />
                                <div>
                                  <h4 style={{ fontSize: '14px', fontWeight: 600, margin: '0 0 4px' }}>{candidate.name}</h4>
                                  <p style={{ fontSize: '12px', color: 'var(--text-secondary)', margin: 0 }}>{candidate.role}</p>
                                </div>
                              </div>
                              <Pressable style={{ color: 'var(--text-secondary)' }}>
                                <MoreVertical size={16} />
                              </Pressable>
                            </div>
                          </Card>
                        </motion.div>
                      ))}
                    </Stagger>
                  </div>
                </Reveal>
              ))}
            </div>
          )}

          {activeTab === 'list' && (
            <Reveal delay={0.1}>
              <div className="glass-panel" style={{ borderRadius: '16px', overflow: 'auto', backgroundColor: 'var(--surface-color)', border: '1px solid var(--border-color)' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '600px' }}>
                  <thead>
                    <tr style={{ backgroundColor: 'var(--bg-color)', borderBottom: '1px solid var(--border-color)' }}>
                      <th style={{ padding: '16px 24px', textAlign: 'left', fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Candidato</th>
                      <th style={{ padding: '16px 24px', textAlign: 'left', fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Fecha</th>
                      <th style={{ padding: '16px 24px', textAlign: 'left', fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Fase</th>
                      <th style={{ padding: '16px 24px', textAlign: 'right', fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Acciones</th>
                    </tr>
                  </thead>
                  <Stagger staggerChildren={0.05} as="tbody">
                    {candidates.map((candidate) => (
                      <motion.tr 
                        layoutId={`candidate-row-${candidate.id}`}
                        key={candidate.id}
                        style={{ borderBottom: '1px solid var(--border-color)' }}
                      >
                        <td style={{ padding: '16px 24px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                            <Avatar name={candidate.name} size={40} />
                            <div>
                              <div style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-primary)' }}>{candidate.name}</div>
                              <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>{candidate.role}</div>
                            </div>
                          </div>
                        </td>
                        <td style={{ padding: '16px 24px', fontSize: '14px', color: 'var(--text-primary)' }}>{candidate.date}</td>
                        <td style={{ padding: '16px 24px' }}>
                          <span style={{ display: 'inline-flex', alignItems: 'center', backgroundColor: 'var(--bg-color)', color: 'var(--text-primary)', padding: '6px 12px', borderRadius: '980px', fontSize: '12px', fontWeight: 600, border: '1px solid var(--border-color)' }}>
                            {columns.find(c => c.id === candidate.status)?.title || candidate.status}
                          </span>
                        </td>
                        <td style={{ padding: '16px 24px', textAlign: 'right' }}>
                          <Pressable style={{ width: '36px', height: '36px', borderRadius: '50%', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-secondary)' }}>
                            <MoreVertical size={16} />
                          </Pressable>
                        </td>
                      </motion.tr>
                    ))}
                  </Stagger>
                </table>
              </div>
            </Reveal>
          )}
        </Crossfade>
      </div>
    </DashboardLayout>
  );
};

export default CompanyDashboard;
