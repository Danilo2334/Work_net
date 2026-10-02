import React from 'react';
import { motion } from 'framer-motion';
import { Check, X, Building2, AlertCircle } from 'lucide-react';
import DashboardLayout from '../components/DashboardLayout';

const AdminDashboard = () => {
  const companies = [
    { id: 1, name: 'TechCorp Solutions', email: 'contact@techcorp.com', date: '2023-10-25', status: 'pending' },
    { id: 2, name: 'DesignStudio', email: 'hello@designstudio.co', date: '2023-10-24', status: 'pending' },
    { id: 3, name: 'DataFlow Systems', email: 'admin@dataflow.io', date: '2023-10-22', status: 'approved' },
  ];

  return (
    <DashboardLayout role="admin">
      <div style={{ maxWidth: '1000px', margin: '0 auto' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
          <div>
            <h1 style={{ fontSize: '32px', marginBottom: '8px' }}>Validación de Empresas</h1>
            <p style={{ color: '#86868b', fontSize: '16px' }}>Revisa y aprueba las solicitudes de nuevas empresas.</p>
          </div>
          <div style={{ backgroundColor: '#fff', padding: '12px 24px', borderRadius: '12px', display: 'flex', gap: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' }}>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '24px', fontWeight: 700, color: '#0066cc' }}>2</div>
              <div style={{ fontSize: '12px', color: '#86868b', textTransform: 'uppercase', fontWeight: 600 }}>Pendientes</div>
            </div>
            <div style={{ width: '1px', backgroundColor: '#e5e5ea' }}></div>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '24px', fontWeight: 700 }}>148</div>
              <div style={{ fontSize: '12px', color: '#86868b', textTransform: 'uppercase', fontWeight: 600 }}>Activas</div>
            </div>
          </div>
        </div>

        <div className="glass-panel" style={{ borderRadius: '16px', overflow: 'hidden', backgroundColor: '#fff' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ backgroundColor: '#f5f5f7', borderBottom: '1px solid #e5e5ea' }}>
                <th style={{ padding: '16px 24px', textAlign: 'left', fontSize: '12px', color: '#86868b', textTransform: 'uppercase', fontWeight: 600 }}>Empresa</th>
                <th style={{ padding: '16px 24px', textAlign: 'left', fontSize: '12px', color: '#86868b', textTransform: 'uppercase', fontWeight: 600 }}>Registro</th>
                <th style={{ padding: '16px 24px', textAlign: 'left', fontSize: '12px', color: '#86868b', textTransform: 'uppercase', fontWeight: 600 }}>Estado</th>
                <th style={{ padding: '16px 24px', textAlign: 'right', fontSize: '12px', color: '#86868b', textTransform: 'uppercase', fontWeight: 600 }}>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {companies.map((company, index) => (
                <motion.tr 
                  key={company.id}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: index * 0.1 }}
                  style={{ borderBottom: '1px solid #e5e5ea' }}
                >
                  <td style={{ padding: '16px 24px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <div style={{ width: '40px', height: '40px', borderRadius: '8px', backgroundColor: '#f5f5f7', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Building2 size={20} color="#86868b" />
                      </div>
                      <div>
                        <div style={{ fontWeight: 600, fontSize: '14px' }}>{company.name}</div>
                        <div style={{ fontSize: '13px', color: '#86868b' }}>{company.email}</div>
                      </div>
                    </div>
                  </td>
                  <td style={{ padding: '16px 24px', fontSize: '14px', color: '#1d1d1f' }}>{company.date}</td>
                  <td style={{ padding: '16px 24px' }}>
                    {company.status === 'pending' ? (
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', backgroundColor: 'rgba(255, 189, 46, 0.2)', color: '#d97706', padding: '4px 10px', borderRadius: '980px', fontSize: '12px', fontWeight: 600 }}>
                        <AlertCircle size={14} /> Pendiente
                      </span>
                    ) : (
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', backgroundColor: 'rgba(39, 201, 63, 0.15)', color: '#16a34a', padding: '4px 10px', borderRadius: '980px', fontSize: '12px', fontWeight: 600 }}>
                        <Check size={14} /> Aprobada
                      </span>
                    )}
                  </td>
                  <td style={{ padding: '16px 24px', textAlign: 'right' }}>
                    {company.status === 'pending' && (
                      <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                        <button style={{ width: '36px', height: '36px', borderRadius: '50%', backgroundColor: 'rgba(39, 201, 63, 0.1)', color: '#16a34a', display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'all 0.2s' }} className="hover-lift">
                          <Check size={18} />
                        </button>
                        <button style={{ width: '36px', height: '36px', borderRadius: '50%', backgroundColor: 'rgba(255, 95, 86, 0.1)', color: '#dc2626', display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'all 0.2s' }} className="hover-lift">
                          <X size={18} />
                        </button>
                      </div>
                    )}
                  </td>
                </motion.tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </DashboardLayout>
  );
};

export default AdminDashboard;
