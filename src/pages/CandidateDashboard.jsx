import React, { useState } from 'react';
import { Search, MapPin, Building, Clock, ChevronRight, Filter, Compass, Bookmark, Send } from 'lucide-react';
import DashboardLayout from '../components/DashboardLayout';
import { Reveal, Stagger } from '../motion/Reveal';
import Card from '../components/common/Card';
import Pressable from '../motion/Pressable';
import FormField from '../components/common/FormField';
import Tabs from '../components/common/Tabs';
import { Crossfade } from '../motion';

const CandidateDashboard = () => {
  const [activeTab, setActiveTab] = useState('explore');

  const jobs = [
    { id: 1, title: 'Senior Frontend Developer', company: 'TechCorp', location: 'Remoto', type: 'Full-time', salary: '$5K - $7K' },
    { id: 2, title: 'Product Designer', company: 'DesignStudio', location: 'Madrid, España', type: 'Full-time', salary: '$4K - $6K' },
    { id: 3, title: 'Backend Engineer', company: 'DataFlow', location: 'Remoto', type: 'Contract', salary: '$60/hr' },
  ];

  const tabs = [
    { id: 'explore', label: 'Explorar', icon: Compass },
    { id: 'saved', label: 'Guardadas', icon: Bookmark },
    { id: 'applications', label: 'Mis Postulaciones', icon: Send },
  ];

  return (
    <DashboardLayout role="candidate">
      <div style={{ maxWidth: '1000px', margin: '0 auto', padding: '32px' }}>
        <Reveal>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '16px' }}>
            <div>
              <h1 style={{ fontSize: '32px', fontWeight: 700, margin: '0 0 8px' }}>Mi Espacio</h1>
              <p style={{ color: 'var(--text-secondary)', fontSize: '16px', margin: 0 }}>Encuentra y gestiona tus oportunidades profesionales.</p>
            </div>
            <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
              <div style={{ position: 'relative', width: '300px' }}>
                <Search style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-secondary)' }} size={20} />
                <input 
                  type="text" 
                  placeholder="Buscar por rol o empresa..." 
                  style={{ 
                    width: '100%',
                    padding: '12px 16px 12px 48px',
                    borderRadius: '12px',
                    border: '1px solid var(--border-color)',
                    backgroundColor: 'var(--surface-color)',
                    color: 'var(--text-primary)',
                    outline: 'none',
                    fontSize: '14px',
                    transition: 'var(--motion-spring-base)'
                  }}
                  onFocus={(e) => e.target.style.borderColor = 'var(--primary-blue)'}
                  onBlur={(e) => e.target.style.borderColor = 'var(--border-color)'}
                />
              </div>
            </div>
          </div>
        </Reveal>

        <Reveal delay={0.1}>
          <div style={{ marginBottom: '32px' }}>
            <Tabs tabs={tabs} value={activeTab} onChange={setActiveTab} />
          </div>
        </Reveal>

        <Crossfade activeKey={activeTab}>
          {activeTab === 'explore' && (
            <div style={{ display: 'flex', gap: '24px', flexWrap: 'wrap' }}>
              <Reveal delay={0.15}>
                <Card className="glass-panel" style={{ width: '260px', flexShrink: 0 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                    <h3 style={{ fontSize: '16px', fontWeight: 600, margin: 0 }}>Filtros</h3>
                    <Filter size={16} color="var(--text-secondary)" />
                  </div>
                  
                  <div style={{ marginBottom: '24px' }}>
                    <span style={{ display: 'block', fontSize: '14px', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '12px' }}>Ubicación</span>
                    {['Remoto', 'Híbrido', 'Presencial'].map(loc => (
                      <label key={loc} style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px', fontSize: '14px', cursor: 'pointer' }}>
                        <input type="checkbox" style={{ accentColor: 'var(--primary-blue)', width: '16px', height: '16px' }} /> {loc}
                      </label>
                    ))}
                  </div>

                  <div>
                    <span style={{ display: 'block', fontSize: '14px', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: '12px' }}>Tipo de Contrato</span>
                    {['Full-time', 'Part-time', 'Freelance'].map(type => (
                      <label key={type} style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px', fontSize: '14px', cursor: 'pointer' }}>
                        <input type="checkbox" style={{ accentColor: 'var(--primary-blue)', width: '16px', height: '16px' }} /> {type}
                      </label>
                    ))}
                  </div>
                </Card>
              </Reveal>

              <Stagger staggerChildren={0.1} style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {jobs.map((job) => (
                  <Card key={job.id} hoverable className="glass-panel" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '24px' }}>
                    <div>
                      <h3 style={{ fontSize: '18px', fontWeight: 600, margin: '0 0 12px' }}>{job.title}</h3>
                      <div style={{ display: 'flex', gap: '20px', color: 'var(--text-secondary)', fontSize: '14px', flexWrap: 'wrap' }}>
                        <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><Building size={16} /> {job.company}</span>
                        <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><MapPin size={16} /> {job.location}</span>
                        <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><Clock size={16} /> {job.type}</span>
                      </div>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                      <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{job.salary}</span>
                      <Pressable style={{ width: '40px', height: '40px', borderRadius: '50%', backgroundColor: 'var(--bg-color)', border: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <ChevronRight size={20} color="var(--primary-blue)" />
                      </Pressable>
                    </div>
                  </Card>
                ))}
              </Stagger>
            </div>
          )}

          {activeTab === 'saved' && (
            <div style={{ padding: '64px', textAlign: 'center', backgroundColor: 'var(--surface-color)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
              <Bookmark size={48} color="var(--border-color)" style={{ margin: '0 auto 16px' }} />
              <h3 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>No hay ofertas guardadas</h3>
              <p style={{ color: 'var(--text-secondary)' }}>Cuando guardes una oferta que te interese, aparecerá aquí.</p>
            </div>
          )}

          {activeTab === 'applications' && (
            <div style={{ padding: '64px', textAlign: 'center', backgroundColor: 'var(--surface-color)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
              <Send size={48} color="var(--border-color)" style={{ margin: '0 auto 16px' }} />
              <h3 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>Aún no te has postulado</h3>
              <p style={{ color: 'var(--text-secondary)' }}>Explora las ofertas y da el primer paso hacia tu nuevo trabajo.</p>
            </div>
          )}
        </Crossfade>
      </div>
    </DashboardLayout>
  );
};

export default CandidateDashboard;
