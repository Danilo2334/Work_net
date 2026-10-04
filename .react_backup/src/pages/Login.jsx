import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Mail, Lock, Eye, ArrowRight, Briefcase, Shield } from 'lucide-react';
import AuthLayout from '../components/auth/AuthLayout';
import Pressable from '../motion/Pressable';

const Login = () => {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({
    email: 'juanmatabanchoyc@gmail.com',
    password: 'password123',
  });

  const handleChange = (e) => {
    setFormData((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleLogin = (e, role) => {
    e.preventDefault();
    navigate(`/${role}`);
  };

  return (
    <AuthLayout
      title="Bienvenido de nuevo"
      subtitle="Inicia sesión para continuar en WorkNet."
      topBadge="admin"
      footer={
        <>
          ¿No tienes cuenta? <Link to="/register" style={{ fontWeight: 600, color: 'var(--primary-blue)', textDecoration: 'none' }}>Regístrate gratis</Link>
        </>
      }
    >
      <form className="auth__form" style={{ padding: 0, backgroundColor: 'transparent' }}>
        
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
          <span style={{ padding: '0 16px' }}>o con tu correo electrónico</span>
          <div style={{ flex: 1, height: '1px', backgroundColor: 'var(--border-color)' }} />
        </div>

        {/* Inputs */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', marginBottom: '24px' }}>
          <div>
            <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '8px' }}>Correo electrónico</label>
            <div style={{ position: 'relative' }}>
              <div style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-secondary)' }}>
                <Mail size={18} />
              </div>
              <input type="email" name="email" value={formData.email} onChange={handleChange} placeholder="juanmatabanchoyc@gmail.com" required style={{ width: '100%', padding: '12px 16px', paddingLeft: '44px', backgroundColor: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px', color: 'var(--text-primary)', outline: 'none', fontSize: '15px' }} />
            </div>
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '8px' }}>Contraseña</label>
            <div style={{ position: 'relative' }}>
              <div style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-secondary)' }}>
                <Lock size={18} />
              </div>
              <input type="password" name="password" value={formData.password} onChange={handleChange} placeholder="••••••••••••••••" required style={{ width: '100%', padding: '12px 16px', paddingLeft: '44px', paddingRight: '44px', backgroundColor: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '12px', color: 'var(--text-primary)', outline: 'none', fontSize: '15px' }} />
              <div style={{ position: 'absolute', right: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-secondary)' }}>
                <Eye size={18} />
              </div>
            </div>
          </div>
        </div>
        
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '13px', color: 'var(--text-primary)' }}>
            <input type="checkbox" defaultChecked /> Recordarme
          </label>
          <a href="#" style={{ fontSize: '13px', fontWeight: 600, color: 'var(--primary-blue)', textDecoration: 'none' }}>¿Olvidaste tu contraseña?</a>
        </div>
        
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <Pressable
            type="button"
            onClick={(e) => handleLogin(e, 'candidate')}
            style={{ width: '100%', padding: '16px', backgroundColor: 'var(--primary-blue)', color: '#fff', fontSize: '15px', fontWeight: 600, borderRadius: '12px', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px' }}
          >
            Entrar como Candidato <ArrowRight size={18} />
          </Pressable>
          <Pressable
            type="button"
            onClick={(e) => handleLogin(e, 'company')}
            style={{ width: '100%', padding: '16px', backgroundColor: '#1e293b', color: '#fff', fontSize: '15px', fontWeight: 600, borderRadius: '12px', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px' }}
          >
            <Briefcase size={18} /> Entrar como Empresa
          </Pressable>
          <Pressable
            type="button"
            onClick={(e) => handleLogin(e, 'admin')}
            style={{ width: '100%', padding: '16px', backgroundColor: 'var(--surface-color)', color: 'var(--text-primary)', border: '1px solid var(--border-color)', fontSize: '15px', fontWeight: 600, borderRadius: '12px', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px' }}
          >
            <Shield size={18} /> Entrar como Admin
          </Pressable>
        </div>

      </form>
    </AuthLayout>
  );
};

export default Login;
