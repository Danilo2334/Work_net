import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowLeft, ShieldCheck } from 'lucide-react';
import BrandLogo from '../common/BrandLogo';
import { Reveal } from '../../motion/Reveal';
import { DURATION, EASE } from '../../motion/tokens';
import './AuthLayout.css';

const AuthLayout = ({ title, subtitle, children, footer, topBadge = false }) => (
  <div className="auth">
    <div className="auth__main">
      <header className="auth__header">
        <BrandLogo />
        <Link to="/" style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-secondary)', textDecoration: 'none', fontSize: '14px', fontWeight: 500 }}>
          <ArrowLeft size={16} /> Volver al inicio
        </Link>
      </header>

      <div className="auth__body">
        <Reveal>
          <div style={{ textAlign: 'center', marginBottom: '32px' }}>
            {topBadge && (
              <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', marginBottom: '24px' }}>
                 <div style={{ width: '28px', height: '28px', backgroundColor: 'var(--primary-blue)', borderRadius: '6px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontWeight: 700, fontSize: '14px' }}>W</div>
                 <span style={{ fontWeight: 700, fontSize: '15px' }}>Work<span style={{ color: 'var(--primary-blue)' }}>_net</span></span>
                 {topBadge === 'admin' && (
                   <span style={{ marginLeft: '12px', padding: '4px 12px', backgroundColor: 'var(--surface-color)', borderRadius: '980px', fontSize: '12px', fontWeight: 600, border: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', gap: '6px' }}>
                     <div style={{ width: 6, height: 6, borderRadius: '50%', backgroundColor: '#10b981' }} /> Sistema Operativo
                   </span>
                 )}
              </div>
            )}
            <h1 style={{ fontSize: '36px', fontWeight: 800, marginBottom: '12px', letterSpacing: '-0.02em' }}>{title}</h1>
            <p style={{ color: 'var(--text-secondary)', fontSize: '15px' }}>{subtitle}</p>
          </div>
          
          {children}
          
          {footer && (
            <div style={{ textAlign: 'center', marginTop: '32px', color: 'var(--text-secondary)', fontSize: '14px' }}>
              {footer}
            </div>
          )}
        </Reveal>
      </div>

      <div style={{ marginTop: 'auto', display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: 'var(--text-secondary)' }}>
        <span>&copy; {new Date().getFullYear()} WorkNet Platform</span>
        <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><ShieldCheck size={14} /> Autenticación Segura</span>
      </div>
    </div>

    <aside className="auth__panel" aria-hidden="true">
      <div className="auth__panel-header">
        <div className="auth__panel-badge">
          <div className="auth__panel-badge-dot" /> Red Global de Reclutamiento
        </div>
        <div style={{ fontSize: '14px', fontWeight: 500, color: 'rgba(255,255,255,0.9)' }}>Enterprise SaaS</div>
      </div>

      <motion.div
        className="auth__panel-content"
        initial={{ opacity: 0, x: 20 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: DURATION.slow * 1.2, delay: 0.1, ease: EASE.out }}
      >
        <h2 className="auth__panel-title">Acelera la contratación del 1% del talento tecnológico más codiciado.</h2>
        <p className="auth__panel-text">WorkNet combina flujos de trabajo basados en datos, evaluación técnica automatizada y matching predictivo para crear equipos imparables.</p>
        
        <div style={{ display: 'flex', gap: '16px', marginBottom: '24px' }}>
          <div style={{ flex: 1, backgroundColor: 'rgba(255,255,255,0.1)', backdropFilter: 'blur(10px)', padding: '24px', borderRadius: '16px', border: '1px solid rgba(255,255,255,0.1)' }}>
            <div style={{ fontSize: '32px', fontWeight: 800, marginBottom: '4px' }}>+85,000</div>
            <div style={{ fontSize: '13px', color: 'rgba(255,255,255,0.8)', fontWeight: 500 }}>Candidatos calificados</div>
          </div>
          <div style={{ flex: 1, backgroundColor: 'rgba(255,255,255,0.1)', backdropFilter: 'blur(10px)', padding: '24px', borderRadius: '16px', border: '1px solid rgba(255,255,255,0.1)' }}>
            <div style={{ fontSize: '32px', fontWeight: 800, marginBottom: '4px' }}>12 días</div>
            <div style={{ fontSize: '13px', color: 'rgba(255,255,255,0.8)', fontWeight: 500 }}>Tiempo promedio de contratación</div>
          </div>
        </div>

        <div style={{ backgroundColor: 'rgba(255,255,255,0.1)', backdropFilter: 'blur(10px)', padding: '32px', borderRadius: '16px', border: '1px solid rgba(255,255,255,0.1)' }}>
          <p style={{ fontStyle: 'italic', fontSize: '15px', lineHeight: 1.6, marginBottom: '24px', color: 'rgba(255,255,255,0.9)' }}>
            "WorkNet transformó por completo nuestro pipeline de ingeniería. Redujimos el tiempo de contratación a la mitad y aumentamos la calidad técnica de las contrataciones."
          </p>
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '50%', backgroundColor: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 600, fontSize: '14px' }}>
              EC
            </div>
            <div>
              <div style={{ fontWeight: 600, fontSize: '14px' }}>Elena Castillo</div>
              <div style={{ fontSize: '12px', color: 'rgba(255,255,255,0.7)' }}>VP de Talento, FinTech Global</div>
            </div>
          </div>
        </div>
      </motion.div>

      <div className="auth__panel-footer">
        <span>Infraestructura SOC2 Type II Certificada</span>
        <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><ShieldCheck size={14} /> Privacidad garantizada</span>
      </div>
    </aside>
  </div>
);

export default AuthLayout;
