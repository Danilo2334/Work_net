import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Search, MapPin, Building, Clock, ChevronRight } from 'lucide-react';
import DashboardLayout from '../components/DashboardLayout';

const CandidateDashboard = () => {
  const [activeTab, setActiveTab] = useState('explore');

  const jobs = [
    { id: 1, title: 'Senior Frontend Developer', company: 'TechCorp', location: 'Remoto', type: 'Full-time', salary: '$5K - $7K' },
    { id: 2, title: 'Product Designer', company: 'DesignStudio', location: 'Madrid, España', type: 'Full-time', salary: '$4K - $6K' },
    { id: 3, title: 'Backend Engineer', company: 'DataFlow', location: 'Remoto', type: 'Contract', salary: '$60/hr' },
  ];

  return (
    <DashboardLayout role="candidate">
      <div style={{ maxWidth: '1000px', margin: '0 auto' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
          <div>
            <h1 style={{ fontSize: '32px', marginBottom: '8px' }}>Explorar Ofertas</h1>
            <p style={{ color: '#86868b', fontSize: '16px' }}>Encuentra tu próximo desafío profesional.</p>
          </div>
          <div style={{ display: 'flex', gap: '12px' }}>
            <div style={{ position: 'relative' }}>
              <Search style={{ position: 'absolute', left: '16px', top: '12px', color: '#86868b' }} size={20} />
              <input 
                type="text" 
                placeholder="Buscar por rol o empresa..." 
                className="input-modern"
                style={{ paddingLeft: '44px', width: '300px' }}
              />
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', gap: '24px', marginBottom: '32px' }}>
          <div style={{ width: '260px', flexShrink: 0 }}>
            <div className="glass-panel" style={{ padding: '24px', borderRadius: '16px' }}>
              <h3 style={{ fontSize: '16px', marginBottom: '16px' }}>Filtros</h3>
              
              <div style={{ marginBottom: '20px' }}>
                <span className="label-modern">Ubicación</span>
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px', fontSize: '14px' }}>
                  <input type="checkbox" /> Remoto
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px', fontSize: '14px' }}>
                  <input type="checkbox" /> Híbrido
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '14px' }}>
                  <input type="checkbox" /> Presencial
                </label>
              </div>

              <div>
                <span className="label-modern">Tipo de Contrato</span>
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px', fontSize: '14px' }}>
                  <input type="checkbox" /> Full-time
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px', fontSize: '14px' }}>
                  <input type="checkbox" /> Part-time
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '14px' }}>
                  <input type="checkbox" /> Freelance
                </label>
              </div>
            </div>
          </div>

          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '16px' }}>
            {jobs.map((job, index) => (
              <motion.div
                key={job.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.3, delay: index * 0.1 }}
                className="glass-panel hover-lift"
                style={{ padding: '24px', borderRadius: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }}
              >
                <div>
                  <h3 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>{job.title}</h3>
                  <div style={{ display: 'flex', gap: '16px', color: '#86868b', fontSize: '14px' }}>
                    <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}><Building size={16} /> {job.company}</span>
                    <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}><MapPin size={16} /> {job.location}</span>
                    <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}><Clock size={16} /> {job.type}</span>
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                  <span style={{ fontWeight: 500 }}>{job.salary}</span>
                  <div style={{ width: '40px', height: '40px', borderRadius: '50%', backgroundColor: '#f5f5f7', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <ChevronRight size={20} color="#0066cc" />
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
};

export default CandidateDashboard;
