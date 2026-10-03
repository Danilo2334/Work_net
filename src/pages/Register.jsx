import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Eye, Check, ArrowRight } from 'lucide-react';
import AuthLayout from '../components/auth/AuthLayout';
import Pressable from '../motion/Pressable';
import { sessionService } from '../services/SessionService';

const Register = () => {
  const navigate = useNavigate();
  const [role, setRole] = useState('candidate');
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    password: '',
  });

  const handleChange = (e) => {
    setFormData((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    try {
      sessionService.register({
        name: formData.name,
        email: formData.email,
        role: role,
        headline: role === 'candidate' ? 'Profesional en búsqueda de oportunidades' : 'Empresa buscando talento'
      });
      navigate('/welcome');
    } catch (err) {
      console.error('Error during registration:', err);
    }
  };

  return (
    <AuthLayout
      title="Crea tu cuenta"
      subtitle="Únete a la plataforma líder para talento y empresas de alto impacto."
      topBadge="default"
      footer={
        <>
          ¿Ya tienes cuenta? <Link to="/login" style={{ fontWeight: 600, color: 'var(--primary-blue)', textDecoration: 'none' }}>Inicia sesión</Link>
        </>
      }
    >
      <form className="auth__form" onSubmit={handleSubmit} style={{ padding: 0, backgroundColor: 'transparent' }}>

        {/* Toggle Role */}
        <div style={{ display: 'flex', gap: '8px', marginBottom: '24px' }}>
          <Pressable
            type="button"
            onClick={() => setRole('candidate')}
            style={{
              borderRadius: '12px', flex: 1, padding: '12px', fontSize: '14px', fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
              backgroundColor: role === 'candidate' ? 'var(--primary-blue)' : 'var(--surface-color)',
              color: role === 'candidate' ? '#fff' : 'var(--text-secondary)',
              border: role === 'candidate' ? '1px solid transparent' : '1px solid var(--border-color)'
            }}
          >
            <div style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: '20px', height: '20px', borderRadius: '50%', border: '1px solid currentColor' }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
            </div>
            Soy Candidato
          </Pressable>
          <Pressable
            type="button"
            onClick={() => setRole('company')}
            style={{
              borderRadius: '12px', flex: 1, padding: '12px', fontSize: '14px', fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
              backgroundColor: role === 'company' ? 'var(--primary-blue)' : 'var(--surface-color)',
              color: role === 'company' ? '#fff' : 'var(--text-secondary)',
              border: role === 'company' ? '1px solid transparent' : '1px solid var(--border-color)'
            }}
          >
            <div style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: '20px', height: '20px', borderRadius: '4px', border: '1px solid currentColor' }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="7" width="20" height="14" rx="2" ry="2"></rect><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"></path></svg>
            </div>
            Soy Empresa
          </Pressable>
        </div>

        {/* Social Buttons */}
        <div style={{ display: 'flex', gap: '16px', marginBottom: '24px' }}>
          <Pressable type="button" style={{ flex: 1, padding: '12px', backgroundColor: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', fontSize: '14px', fontWeight: 600, color: 'var(--text-primary)' }}>
            <img src="https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg" alt="Google" width="16" height="16" /> Google
          </Pressable>
          <Pressable type="button" style={{ flex: 1, padding: '12px', backgroundColor: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', fontSize: '14px', fontWeight: 600, color: 'var(--text-primary)' }}>
            <img src="https://upload.wikimedia.org/wikipedia/commons/c/ca/LinkedIn_logo_initials.png" alt="LinkedIn" width="16" height="16" style={{ borderRadius: 2 }} /> LinkedIn
          </Pressable>
        </div>

        {/* Divider */}
        <div style={{ display: 'flex', alignItems: 'center', margin: '24px 0', color: 'var(--text-secondary)', fontSize: '11px', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          <div style={{ flex: 1, height: '1px', backgroundColor: 'var(--border-color)' }} />
          <span style={{ padding: '0 16px' }}>O completa tus datos</span>
          <div style={{ flex: 1, height: '1px', backgroundColor: 'var(--border-color)' }} />
        </div>

        {/* Inputs */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div>
            <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '8px' }}>Nombre completo</label>
            <div style={{ position: 'relative' }}>
              <input type="text" name="name" value={formData.name} onChange={handleChange} placeholder="Juan Pérez" required style={{ width: '100%', padding: '12px 16px', paddingRight: '48px', backgroundColor: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px', color: 'var(--text-primary)', outline: 'none', fontSize: '15px' }} />
              <div style={{ position: 'absolute', right: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-secondary)' }}>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 22h14a2 2 0 0 0 2-2V7.5L14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2z"></path><polyline points="14 2 14 8 20 8"></polyline><path d="M10.5 13.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z"></path><path d="M6 18c0-1.5 2.5-2.5 4.5-2.5s4.5 1 4.5 2.5"></path></svg>
              </div>
            </div>
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '8px' }}>Correo electrónico</label>
            <div style={{ position: 'relative' }}>
              <input type="email" name="email" value={formData.email} onChange={handleChange} placeholder="example@gmail.com" required style={{ width: '100%', padding: '12px 16px', paddingRight: '48px', backgroundColor: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px', color: 'var(--text-primary)', outline: 'none', fontSize: '15px' }} />
              <div style={{ position: 'absolute', right: '16px', top: '50%', transform: 'translateY(-50%)', color: '#10b981' }}>
                <Check size={18} />
              </div>
            </div>
          </div>

          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)' }}>Contraseña</label>
              <span style={{ fontSize: '12px', fontWeight: 600, color: '#10b981', display: 'flex', alignItems: 'center', gap: '4px' }}>
                <div style={{ width: 6, height: 6, borderRadius: '50%', backgroundColor: '#10b981' }} />
                Seguridad: Fuerte
              </span>
            </div>
            <div style={{ position: 'relative', marginBottom: '8px' }}>
              <input type="password" name="password" value={formData.password} onChange={handleChange} placeholder="••••••••••••••••" required style={{ width: '100%', padding: '12px 16px', paddingRight: '48px', backgroundColor: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px', color: 'var(--text-primary)', outline: 'none', fontSize: '15px' }} />
              <div style={{ position: 'absolute', right: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-secondary)' }}>
                <Eye size={18} />
              </div>
            </div>
            <div style={{ display: 'flex', gap: '4px', height: '4px' }}>
              <div style={{ flex: 1, backgroundColor: '#10b981', borderRadius: '2px' }} />
              <div style={{ flex: 1, backgroundColor: '#10b981', borderRadius: '2px' }} />
              <div style={{ flex: 1, backgroundColor: '#10b981', borderRadius: '2px' }} />
              <div style={{ flex: 1, backgroundColor: '#10b981', borderRadius: '2px' }} />
            </div>
          </div>
        </div>

        <label style={{ display: 'flex', alignItems: 'flex-start', gap: '12px', margin: '24px 0', cursor: 'pointer' }}>
          <input type="checkbox" required defaultChecked style={{ marginTop: '4px' }} />
          <span style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: 1.5 }}>
            Acepto los <a href="#" style={{ color: 'var(--primary-blue)', fontWeight: 600, textDecoration: 'none' }}>Términos de Servicio</a> y la <a href="#" style={{ color: 'var(--primary-blue)', fontWeight: 600, textDecoration: 'none' }}>Política de Privacidad</a> de WorkNet.
          </span>
        </label>

        <Pressable
          type="submit"
          style={{ width: '100%', padding: '16px', backgroundColor: 'var(--primary-blue)', color: '#fff', fontSize: '16px', fontWeight: 600, borderRadius: '12px', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px' }}
        >
          Registrarme gratis <ArrowRight size={18} />
        </Pressable>

      </form>
    </AuthLayout>
  );
};

export default Register;
