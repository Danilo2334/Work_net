import React, { useSyncExternalStore } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import DashboardLayout from '../components/DashboardLayout';
import { sessionService } from '../services/SessionService';
import Card from '../components/common/Card';
import StatCard from '../components/common/StatCard';
import { Reveal, Stagger } from '../motion/Reveal';
import Pressable from '../motion/Pressable';
import { Briefcase, Building, MapPin, User, ChevronRight, Zap } from 'lucide-react';
import { Avatar } from '../components/common/Misc';

const Welcome = () => {
  const user = useSyncExternalStore(sessionService.subscribe, sessionService.getUser);
  const navigate = useNavigate();

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  const isCandidate = user.role === 'candidate';

  const handleContinue = () => {
    navigate(`/${user.role}`);
  };

  return (
    <DashboardLayout role={user.role}>
      <div style={{ maxWidth: '1000px', margin: '0 auto', padding: '32px' }}>
        <Reveal>
          <div style={{ display: 'flex', alignItems: 'center', gap: '24px', marginBottom: '40px' }}>
            <Avatar name={user.name} size={80} />
            <div>
              <h1 style={{ fontSize: '36px', fontWeight: 700, margin: '0 0 8px' }}>
                ¡Bienvenido a WorkNet, {user.name.split(' ')[0]}!
              </h1>
              <p style={{ fontSize: '18px', color: 'var(--text-secondary)', margin: 0 }}>
                Tu cuenta de {isCandidate ? 'candidato' : 'empresa'} está lista para usarse.
              </p>
            </div>
          </div>
        </Reveal>

        <Stagger staggerChildren={0.15}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '24px', marginBottom: '32px' }}>
            <Card hoverable className="glass-panel">
              <h3 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <User size={24} color="var(--primary-blue)" /> Perfil
              </h3>
              <p style={{ color: 'var(--text-secondary)', marginBottom: '8px' }}>
                <strong>Nombre:</strong> {user.name}
              </p>
              <p style={{ color: 'var(--text-secondary)', marginBottom: '8px' }}>
                <strong>Correo:</strong> {user.email}
              </p>
              <p style={{ color: 'var(--text-secondary)' }}>
                <strong>Titular:</strong> {user.headline}
              </p>
            </Card>

            <Card hoverable className="glass-panel" style={{ display: 'flex', flexDirection: 'column' }}>
              <h3 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Zap size={24} color="var(--primary-blue)" /> Siguientes Pasos
              </h3>
              <p style={{ color: 'var(--text-secondary)', marginBottom: 'auto', lineHeight: '1.5' }}>
                {isCandidate 
                  ? 'Completa tu perfil subiendo tu currículum y destacando tus habilidades para que las mejores empresas te encuentren.'
                  : 'Publica tu primera oferta de empleo para comenzar a recibir solicitudes del mejor talento disponible.'}
              </p>
              <div style={{ marginTop: '24px' }}>
                <Pressable
                  className="btn btn-primary btn-block"
                  onClick={handleContinue}
                  style={{ borderRadius: '12px', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px' }}
                >
                  Ir al Dashboard <ChevronRight size={18} />
                </Pressable>
              </div>
            </Card>
          </div>

          <Reveal>
            <h2 style={{ fontSize: '24px', fontWeight: 600, marginBottom: '24px', marginTop: '48px' }}>
              {isCandidate ? 'Ofertas Sugeridas' : 'Candidatos Destacados'}
            </h2>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {isCandidate ? (
                <>
                  <Card hoverable className="glass-panel" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <h4 style={{ fontSize: '18px', fontWeight: 500, marginBottom: '8px' }}>Senior React Developer</h4>
                      <div style={{ display: 'flex', gap: '16px', color: 'var(--text-secondary)', fontSize: '14px' }}>
                        <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}><Building size={16} /> InnovaTech</span>
                        <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}><MapPin size={16} /> Remoto</span>
                      </div>
                    </div>
                    <Pressable className="btn btn-outline" style={{ borderRadius: '12px', padding: '8px 16px' }}>Ver</Pressable>
                  </Card>
                  <Card hoverable className="glass-panel" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <h4 style={{ fontSize: '18px', fontWeight: 500, marginBottom: '8px' }}>Frontend Engineer</h4>
                      <div style={{ display: 'flex', gap: '16px', color: 'var(--text-secondary)', fontSize: '14px' }}>
                        <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}><Building size={16} /> StartupLabs</span>
                        <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}><MapPin size={16} /> Madrid, ES</span>
                      </div>
                    </div>
                    <Pressable className="btn btn-outline" style={{ borderRadius: '12px', padding: '8px 16px' }}>Ver</Pressable>
                  </Card>
                </>
              ) : (
                <>
                  <Card hoverable className="glass-panel" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                      <Avatar name="Carlos Mendoza" size={48} />
                      <div>
                        <h4 style={{ fontSize: '18px', fontWeight: 500, marginBottom: '4px' }}>Carlos Mendoza</h4>
                        <p style={{ color: 'var(--text-secondary)', fontSize: '14px', margin: 0 }}>Full-stack Developer | 5+ Años Exp</p>
                      </div>
                    </div>
                    <Pressable className="btn btn-outline" style={{ borderRadius: '12px', padding: '8px 16px' }}>Ver Perfil</Pressable>
                  </Card>
                  <Card hoverable className="glass-panel" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                      <Avatar name="Elena Gómez" size={48} />
                      <div>
                        <h4 style={{ fontSize: '18px', fontWeight: 500, marginBottom: '4px' }}>Elena Gómez</h4>
                        <p style={{ color: 'var(--text-secondary)', fontSize: '14px', margin: 0 }}>UI/UX Designer | Figma Expert</p>
                      </div>
                    </div>
                    <Pressable className="btn btn-outline" style={{ borderRadius: '12px', padding: '8px 16px' }}>Ver Perfil</Pressable>
                  </Card>
                </>
              )}
            </div>
          </Reveal>
        </Stagger>
      </div>
    </DashboardLayout>
  );
};

export default Welcome;
