import React from 'react';
import { motion } from 'framer-motion';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowRight, Sparkles, ShieldCheck, Zap } from 'lucide-react';
import BrandLogo from '../components/common/BrandLogo';
import ThemeToggle from '../components/common/ThemeToggle';
import { Reveal, Stagger } from '../motion/Reveal';
import Card from '../components/common/Card';
import Pressable from '../motion/Pressable';
import ShaderBackground from '../components/common/ShaderBackground';

const Landing = () => {
  const navigate = useNavigate();

  return (
    <div style={{ minHeight: '100vh', backgroundColor: 'var(--bg-color)', color: 'var(--text-primary)', position: 'relative' }}>
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: '800px', zIndex: 0, opacity: 0.5, pointerEvents: 'none' }}>
        <ShaderBackground />
      </div>

      <div style={{ position: 'relative', zIndex: 1 }}>
        {/* Navigation */}
        <nav className="glass-nav" style={{ padding: '16px 0' }}>
          <div className="container" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <BrandLogo />
            <div style={{ display: 'flex', gap: '24px', alignItems: 'center' }}>
              <ThemeToggle />
              <Link to="/login" style={{ fontWeight: 500, color: 'var(--text-primary)', textDecoration: 'none', transition: 'var(--motion-spring-base)' }}>
                Iniciar Sesión
              </Link>
              <Pressable 
                onClick={() => navigate('/register')}
                style={{ backgroundColor: 'var(--text-primary)', color: 'var(--bg-color)', padding: '10px 20px', borderRadius: '980px', fontWeight: 500, display: 'flex', alignItems: 'center', gap: '8px' }}
              >
                Registrarse
              </Pressable>
            </div>
          </div>
        </nav>

        {/* Hero Section */}
        <section style={{ padding: '120px 0 80px', textAlign: 'center', overflow: 'hidden' }}>
          <div className="container">
            <Reveal>
              <h1 style={{ fontSize: '72px', fontWeight: 700, letterSpacing: '-0.04em', lineHeight: 1.1, marginBottom: '24px' }}>
                El futuro del <span className="text-gradient">reclutamiento</span>. <br /> Simple. Inteligente.
              </h1>
              <p style={{ fontSize: '24px', color: 'var(--text-secondary)', maxWidth: '700px', margin: '0 auto 48px', fontWeight: 400, lineHeight: 1.4 }}>
                Conecta talento excepcional con las mejores empresas usando una plataforma diseñada para la excelencia y velocidad.
              </p>
              <div style={{ display: 'flex', justifyContent: 'center', gap: '16px' }}>
                <Pressable 
                  className="btn btn-primary"
                  onClick={() => navigate('/candidate')}
                  style={{ borderRadius: '980px', fontSize: '18px', padding: '16px 32px', display: 'flex', alignItems: 'center', gap: '8px' }}
                >
                  Soy Candidato <ArrowRight size={20} />
                </Pressable>
                <Pressable 
                  className="btn btn-outline"
                  onClick={() => navigate('/company')}
                  style={{ borderRadius: '980px', fontSize: '18px', padding: '16px 32px' }}
                >
                  Soy Empresa
                </Pressable>
              </div>
            </Reveal>
          </div>
        </section>

        {/* Features as Footer Cards */}
        <section style={{ padding: '40px 0 100px', backgroundColor: 'transparent' }}>
          <div className="container">
            <Stagger staggerChildren={0.15} style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '32px' }}>
              {[
                { icon: <Sparkles size={32} color="var(--primary-blue)" />, title: 'Diseño Premium', desc: 'Una interfaz diseñada obsesivamente para la mejor experiencia de usuario.' },
                { icon: <Zap size={32} color="var(--primary-blue)" />, title: 'Rápido y Fluido', desc: 'Navegación instantánea y animaciones naturales que se sienten nativas.' },
                { icon: <ShieldCheck size={32} color="var(--primary-blue)" />, title: 'Empresas Validadas', desc: 'Un entorno seguro con ofertas reales y empresas verificadas.' }
              ].map((f, i) => (
                <Card hoverable key={i} className="glass-panel" style={{ padding: '40px', borderRadius: '24px', backgroundColor: 'var(--surface-color)', cursor: 'default' }}>
                  <div style={{ marginBottom: '20px' }}>{f.icon}</div>
                  <h3 style={{ fontSize: '24px', marginBottom: '12px', fontWeight: 600 }}>{f.title}</h3>
                  <p style={{ color: 'var(--text-secondary)', fontSize: '16px', lineHeight: 1.5 }}>{f.desc}</p>
                </Card>
              ))}
            </Stagger>
          </div>
        </section>
      </div>

      {/* Footer */}
      <footer style={{ borderTop: '1px solid var(--border-color)', backgroundColor: 'var(--bg-color)', padding: '40px 0', marginTop: 'auto', position: 'relative', zIndex: 1 }}>
        <div className="container" style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '32px' }}>
            <div>
              <BrandLogo />
              <p style={{ color: 'var(--text-secondary)', fontSize: '14px', marginTop: '16px', maxWidth: '300px' }}>
                Conectando el mejor talento con las empresas más innovadoras a través de tecnología inteligente.
              </p>
            </div>
            
            <div style={{ display: 'flex', gap: '64px', flexWrap: 'wrap' }}>
              <div>
                <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '16px', color: 'var(--text-primary)' }}>Plataforma</h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <Link to="/candidate" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Para Candidatos</Link>
                  <Link to="/company" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Para Empresas</Link>
                  <Link to="/login" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Iniciar Sesión</Link>
                </div>
              </div>
              
              <div>
                <h4 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '16px', color: 'var(--text-primary)' }}>Legal</h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <a href="#" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Privacidad</a>
                  <a href="#" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Términos de Servicio</a>
                  <a href="#" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Cookies</a>
                </div>
              </div>
            </div>
          </div>
          
          <div style={{ paddingTop: '24px', borderTop: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
            <p style={{ color: 'var(--text-secondary)', fontSize: '12px', margin: 0 }}>
              &copy; {new Date().getFullYear()} WorkNet. Todos los derechos reservados.
            </p>
            <div style={{ display: 'flex', gap: '16px' }}>
              <ThemeToggle />
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default Landing;
