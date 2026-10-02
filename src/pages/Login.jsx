import React from 'react';
import { motion } from 'framer-motion';
import { Link, useNavigate } from 'react-router-dom';

const Login = () => {
  const navigate = useNavigate();

  const handleLogin = (e, role) => {
    e.preventDefault();
    navigate(`/${role}`);
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', backgroundColor: '#f5f5f7' }}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '32px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: 'auto' }}>
          <Link to="/" style={{ display: 'flex', alignItems: 'center', gap: '8px', textDecoration: 'none', color: '#1d1d1f' }}>
            <div className="w-8 h-8 rounded-lg flex items-center justify-center text-white font-bold" style={{ backgroundColor: '#0066cc', width: 32, height: 32, borderRadius: 8 }}>
              W
            </div>
            <span className="font-bold text-xl tracking-tight" style={{ fontWeight: 700, fontSize: '20px' }}>WorkNet</span>
          </Link>
        </div>

        <div style={{ margin: 'auto', width: '100%', maxWidth: '400px' }}>
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
          >
            <h1 style={{ fontSize: '32px', fontWeight: 700, marginBottom: '8px', textAlign: 'center' }}>Bienvenido de nuevo</h1>
            <p style={{ color: '#86868b', textAlign: 'center', marginBottom: '32px' }}>Inicia sesión para continuar en WorkNet.</p>

            <form className="glass-panel" style={{ padding: '32px', borderRadius: '24px', backgroundColor: '#fff' }}>
              <div className="form-group">
                <label className="label-modern">Correo electrónico</label>
                <input type="email" placeholder="nombre@ejemplo.com" className="input-modern" />
              </div>
              <div className="form-group">
                <label className="label-modern">Contraseña</label>
                <input type="password" placeholder="••••••••" className="input-modern" />
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '14px', color: '#86868b' }}>
                  <input type="checkbox" /> Recordarme
                </label>
                <a href="#" style={{ fontSize: '14px', color: '#0066cc', textDecoration: 'none', fontWeight: 500 }}>¿Olvidaste tu contraseña?</a>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <button 
                  onClick={(e) => handleLogin(e, 'candidate')}
                  style={{ width: '100%', backgroundColor: '#0066cc', color: '#fff', padding: '14px', borderRadius: '12px', fontSize: '16px', fontWeight: 600, transition: 'all 0.2s' }}
                  className="hover-lift"
                >
                  Entrar como Candidato
                </button>
                <button 
                  onClick={(e) => handleLogin(e, 'company')}
                  style={{ width: '100%', backgroundColor: '#1d1d1f', color: '#fff', padding: '14px', borderRadius: '12px', fontSize: '16px', fontWeight: 600, transition: 'all 0.2s' }}
                  className="hover-lift"
                >
                  Entrar como Empresa
                </button>
                <button 
                  onClick={(e) => handleLogin(e, 'admin')}
                  style={{ width: '100%', backgroundColor: 'transparent', border: '1px solid #d2d2d7', color: '#1d1d1f', padding: '14px', borderRadius: '12px', fontSize: '16px', fontWeight: 600, transition: 'all 0.2s' }}
                  className="hover-lift"
                >
                  Entrar como Admin
                </button>
              </div>
            </form>
            
            <p style={{ textAlign: 'center', marginTop: '32px', color: '#86868b', fontSize: '14px' }}>
              ¿No tienes cuenta? <Link to="/register" style={{ color: '#0066cc', fontWeight: 500, textDecoration: 'none' }}>Regístrate</Link>
            </p>
          </motion.div>
        </div>
      </div>

      <div style={{ flex: 1, backgroundColor: '#0066cc', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', top: '-10%', left: '-10%', width: '120%', height: '120%', background: 'radial-gradient(circle at 50% 50%, rgba(255,255,255,0.1) 0%, transparent 60%)' }}></div>
        <div style={{ padding: '64px', maxWidth: '600px', color: '#fff', zIndex: 1 }}>
          <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} transition={{ duration: 0.8, delay: 0.2 }}>
            <h2 style={{ fontSize: '48px', fontWeight: 700, marginBottom: '24px', lineHeight: 1.1 }}>Donde el talento encuentra su lugar.</h2>
            <p style={{ fontSize: '20px', color: 'rgba(255,255,255,0.8)', lineHeight: 1.5 }}>
              Únete a miles de profesionales y empresas que ya están transformando su futuro con WorkNet.
            </p>
          </motion.div>
        </div>
      </div>
    </div>
  );
};

export default Login;
