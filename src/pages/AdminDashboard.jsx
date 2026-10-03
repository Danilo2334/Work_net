import React, { useState } from 'react';
import { Check, X, Building2, AlertCircle, List, Clock, CheckCircle2 } from 'lucide-react';
import DashboardLayout from '../components/DashboardLayout';
import { Reveal, Stagger } from '../motion/Reveal';
import Card from '../components/common/Card';
import Pressable from '../motion/Pressable';
import { motion } from 'framer-motion';
import Tabs from '../components/common/Tabs';
import { Crossfade } from '../motion';

const AdminDashboard = () => {
  const [activeTab, setActiveTab] = useState('all');

  const companies = [
    { id: 1, name: 'TechCorp Solutions', email: 'contact@techcorp.com', date: '2023-10-25', status: 'pending' },
    { id: 2, name: 'DesignStudio', email: 'hello@designstudio.co', date: '2023-10-24', status: 'pending' },
    { id: 3, name: 'DataFlow Systems', email: 'admin@dataflow.io', date: '2023-10-22', status: 'approved' },
  ];

  const filteredCompanies = activeTab === 'all' 
    ? companies 
    : companies.filter(c => c.status === activeTab);

  const tabs = [
    { id: 'all', label: 'Todas', icon: List },
    { id: 'pending', label: 'Pendientes', icon: Clock },
    { id: 'approved', label: 'Aprobadas', icon: CheckCircle2 },
  ];

  return (
    <DashboardLayout role="admin">
      <div style={{ maxWidth: '1000px', margin: '0 auto', padding: '32px' }}>
        <Reveal>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px', flexWrap: 'wrap', gap: '24px' }}>
            <div>
              <h1 style={{ fontSize: '32px', fontWeight: 700, margin: '0 0 8px' }}>Validación de Empresas</h1>
              <p style={{ color: 'var(--text-secondary)', fontSize: '16px', margin: 0 }}>Revisa y aprueba las solicitudes de nuevas empresas.</p>
            </div>
          </div>
        </Reveal>

        <Reveal delay={0.1}>
          <div style={{ marginBottom: '24px' }}>
            <Tabs tabs={tabs} value={activeTab} onChange={setActiveTab} />
          </div>
        </Reveal>

        <Reveal delay={0.15}>
          <Crossfade activeKey={activeTab}>
            <div className="glass-panel" style={{ borderRadius: '16px', overflow: 'auto', backgroundColor: 'var(--surface-color)', border: '1px solid var(--border-color)', marginBottom: '32px' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '600px' }}>
                <thead>
                  <tr style={{ backgroundColor: 'var(--bg-color)', borderBottom: '1px solid var(--border-color)' }}>
                    <th style={{ padding: '16px 24px', textAlign: 'left', fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Empresa</th>
                    <th style={{ padding: '16px 24px', textAlign: 'left', fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Registro</th>
                    <th style={{ padding: '16px 24px', textAlign: 'left', fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Estado</th>
                    <th style={{ padding: '16px 24px', textAlign: 'right', fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Acciones</th>
                  </tr>
                </thead>
                <Stagger staggerChildren={0.05} as="tbody">
                  {filteredCompanies.map((company) => (
                    <motion.tr 
                      key={company.id}
                      style={{ borderBottom: '1px solid var(--border-color)' }}
                    >
                      <td style={{ padding: '16px 24px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <div style={{ width: '40px', height: '40px', borderRadius: '8px', backgroundColor: 'var(--bg-color)', border: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            <Building2 size={20} color="var(--text-secondary)" />
                          </div>
                          <div>
                            <div style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-primary)' }}>{company.name}</div>
                            <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>{company.email}</div>
                          </div>
                        </div>
                      </td>
                      <td style={{ padding: '16px 24px', fontSize: '14px', color: 'var(--text-primary)' }}>{company.date}</td>
                      <td style={{ padding: '16px 24px' }}>
                        {company.status === 'pending' ? (
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', backgroundColor: 'rgba(255, 189, 46, 0.15)', color: '#d97706', padding: '6px 12px', borderRadius: '980px', fontSize: '12px', fontWeight: 600 }}>
                            <AlertCircle size={14} /> Pendiente
                          </span>
                        ) : (
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', backgroundColor: 'rgba(39, 201, 63, 0.15)', color: '#16a34a', padding: '6px 12px', borderRadius: '980px', fontSize: '12px', fontWeight: 600 }}>
                            <Check size={14} /> Aprobada
                          </span>
                        )}
                      </td>
                      <td style={{ padding: '16px 24px', textAlign: 'right' }}>
                        {company.status === 'pending' && (
                          <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                            <Pressable style={{ width: '36px', height: '36px', borderRadius: '50%', backgroundColor: 'rgba(39, 201, 63, 0.1)', color: '#16a34a', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                              <Check size={18} />
                            </Pressable>
                            <Pressable style={{ width: '36px', height: '36px', borderRadius: '50%', backgroundColor: 'rgba(255, 95, 86, 0.1)', color: '#dc2626', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                              <X size={18} />
                            </Pressable>
                          </div>
                        )}
                      </td>
                    </motion.tr>
                  ))}
                </Stagger>
              </table>
              {filteredCompanies.length === 0 && (
                <div style={{ padding: '48px', textAlign: 'center', color: 'var(--text-secondary)' }}>
                  No hay empresas en esta categoría.
                </div>
              )}
            </div>
          </Crossfade>
        </Reveal>

        <Reveal delay={0.2}>
          <Card hoverable className="glass-panel" style={{ padding: '24px', display: 'flex', gap: '32px', justifyContent: 'center', maxWidth: '400px', margin: '0 auto', cursor: 'default' }}>
            <div style={{ textAlign: 'center', flex: 1 }}>
              <div style={{ fontSize: '32px', fontWeight: 700, color: 'var(--primary-blue)' }}>2</div>
              <div style={{ fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600, letterSpacing: '0.05em' }}>Pendientes</div>
            </div>
            <div style={{ width: '1px', backgroundColor: 'var(--border-color)' }}></div>
            <div style={{ textAlign: 'center', flex: 1 }}>
              <div style={{ fontSize: '32px', fontWeight: 700, color: 'var(--text-primary)' }}>148</div>
              <div style={{ fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600, letterSpacing: '0.05em' }}>Activas</div>
            </div>
          </Card>
        </Reveal>
      </div>
    </DashboardLayout>
  );
};

export default AdminDashboard;
