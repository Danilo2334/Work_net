import React from 'react';
import { motion } from 'framer-motion';
import { Plus, MoreVertical } from 'lucide-react';
import DashboardLayout from '../components/DashboardLayout';

const CompanyDashboard = () => {
  const columns = [
    { id: 'new', title: 'Nuevos', count: 3 },
    { id: 'review', title: 'En Revisión', count: 2 },
    { id: 'interview', title: 'Entrevistas', count: 1 },
    { id: 'offer', title: 'Oferta', count: 0 },
  ];

  const candidates = [
    { id: 1, name: 'Alex Johnson', role: 'Frontend Dev', status: 'new', img: 'https://i.pravatar.cc/150?u=1' },
    { id: 2, name: 'Sarah Miller', role: 'UX Designer', status: 'new', img: 'https://i.pravatar.cc/150?u=2' },
    { id: 3, name: 'Michael Chen', role: 'Fullstack', status: 'new', img: 'https://i.pravatar.cc/150?u=3' },
    { id: 4, name: 'Emma Davis', role: 'Product Manager', status: 'review', img: 'https://i.pravatar.cc/150?u=4' },
    { id: 5, name: 'James Wilson', role: 'Backend Dev', status: 'review', img: 'https://i.pravatar.cc/150?u=5' },
    { id: 6, name: 'Olivia Taylor', role: 'Frontend Dev', status: 'interview', img: 'https://i.pravatar.cc/150?u=6' },
  ];

  return (
    <DashboardLayout role="company">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
        <div>
          <h1 style={{ fontSize: '32px', marginBottom: '8px' }}>Gestión de Candidatos</h1>
          <p style={{ color: '#86868b', fontSize: '16px' }}>Rol activo: Senior Frontend Developer</p>
        </div>
        <button style={{ backgroundColor: '#0066cc', color: '#fff', padding: '12px 24px', borderRadius: '980px', fontWeight: 500, display: 'flex', alignItems: 'center', gap: '8px' }} className="hover-lift">
          <Plus size={20} /> Nueva Oferta
        </button>
      </div>

      <div className="kanban-board">
        {columns.map((column, colIndex) => (
          <div key={column.id} className="kanban-column">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', padding: '0 8px' }}>
              <h3 style={{ fontSize: '15px', fontWeight: 600 }}>{column.title}</h3>
              <span style={{ backgroundColor: '#e5e5ea', color: '#1d1d1f', padding: '2px 8px', borderRadius: '12px', fontSize: '12px', fontWeight: 600 }}>
                {column.count}
              </span>
            </div>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', flex: 1 }}>
              {candidates.filter(c => c.status === column.id).map((candidate, i) => (
                <motion.div
                  key={candidate.id}
                  layoutId={`candidate-${candidate.id}`}
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ duration: 0.2, delay: i * 0.05 }}
                  className="glass-panel hover-lift"
                  style={{ padding: '16px', borderRadius: '12px', cursor: 'grab', backgroundColor: '#fff' }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div style={{ display: 'flex', gap: '12px' }}>
                      <img src={candidate.img} alt={candidate.name} style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover' }} />
                      <div>
                        <h4 style={{ fontSize: '14px', fontWeight: 600 }}>{candidate.name}</h4>
                        <p style={{ fontSize: '12px', color: '#86868b' }}>{candidate.role}</p>
                      </div>
                    </div>
                    <button style={{ color: '#86868b' }}><MoreVertical size={16} /></button>
                  </div>
                </motion.div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </DashboardLayout>
  );
};

export default CompanyDashboard;
