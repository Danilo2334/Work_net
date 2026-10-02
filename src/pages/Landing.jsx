import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowRight, Sparkles, ShieldCheck, Zap } from 'lucide-react';

const Landing = () => {
  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#ffffff', color: '#1d1d1f' }}>
      {/* Navigation */}
      <nav className="glass-nav" style={{ padding: '16px 0' }}>
        <div className="container" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg flex items-center justify-center text-white font-bold" style={{ backgroundColor: '#0066cc', width: 32, height: 32, borderRadius: 8 }}>
              W
            </div>
            <span className="font-bold text-xl tracking-tight" style={{ fontWeight: 700, fontSize: '20px' }}>WorkNet</span>
          </div>
          <div className="flex gap-4 items-center" style={{ display: 'flex', gap: '24px', alignItems: 'center' }}>
            <Link to="/login" style={{ fontWeight: 500, color: '#1d1d1f', textDecoration: 'none' }}>Iniciar Sesión</Link>
            <Link to="/login" style={{ backgroundColor: '#1d1d1f', color: '#fff', padding: '10px 20px', borderRadius: '980px', fontWeight: 500, textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '8px' }}>
              Registrarse
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section style={{ padding: '120px 0 80px', textAlign: 'center', overflow: 'hidden' }}>
        <div className="container">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
          >
            <h1 style={{ fontSize: '72px', fontWeight: 700, letterSpacing: '-0.04em', lineHeight: 1.1, marginBottom: '24px' }}>
              El futuro del <span className="text-gradient">reclutamiento</span>. <br /> Simple. Inteligente.
            </h1>
            <p style={{ fontSize: '24px', color: '#86868b', maxWidth: '700px', margin: '0 auto 48px', fontWeight: 400, lineHeight: 1.4 }}>
              Conecta talento excepcional con las mejores empresas usando una plataforma diseñada para la excelencia y velocidad.
            </p>
            <div style={{ display: 'flex', justifyContent: 'center', gap: '16px' }}>
              <Link to="/candidate" style={{ backgroundColor: '#0066cc', color: '#fff', padding: '16px 32px', borderRadius: '980px', fontSize: '18px', fontWeight: 500, textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '8px', transition: 'all 0.2s' }} className="hover-lift">
                Soy Candidato <ArrowRight size={20} />
              </Link>
              <Link to="/company" style={{ backgroundColor: 'rgba(0,0,0,0.05)', color: '#1d1d1f', padding: '16px 32px', borderRadius: '980px', fontSize: '18px', fontWeight: 500, textDecoration: 'none', transition: 'all 0.2s' }} className="hover-lift">
                Soy Empresa
              </Link>
            </div>
          </motion.div>
          
          <motion.div 
            initial={{ opacity: 0, y: 50 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 1, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
            style={{ marginTop: '80px', position: 'relative' }}
          >
            <div style={{ width: '100%', maxWidth: '1000px', margin: '0 auto', height: '600px', backgroundColor: '#f5f5f7', borderRadius: '24px', border: '1px solid #d2d2d7', boxShadow: '0 24px 48px rgba(0,0,0,0.08)', overflow: 'hidden', position: 'relative' }}>
               <div style={{ width: '100%', height: '40px', borderBottom: '1px solid #d2d2d7', display: 'flex', alignItems: 'center', padding: '0 16px', gap: '8px', backgroundColor: 'rgba(255,255,255,0.5)' }}>
                 <div style={{ width: 12, height: 12, borderRadius: '50%', backgroundColor: '#ff5f56' }} />
                 <div style={{ width: 12, height: 12, borderRadius: '50%', backgroundColor: '#ffbd2e' }} />
                 <div style={{ width: 12, height: 12, borderRadius: '50%', backgroundColor: '#27c93f' }} />
               </div>
               <div style={{ padding: '40px', display: 'flex', gap: '24px', height: 'calc(100% - 40px)' }}>
                 <div style={{ width: '200px', backgroundColor: '#fff', borderRadius: '12px', padding: '16px', boxShadow: '0 4px 12px rgba(0,0,0,0.05)' }}>
                    <div style={{ width: '100%', height: '24px', backgroundColor: '#f5f5f7', borderRadius: '6px', marginBottom: '16px' }} />
                    <div style={{ width: '80%', height: '16px', backgroundColor: '#f5f5f7', borderRadius: '4px', marginBottom: '12px' }} />
                    <div style={{ width: '90%', height: '16px', backgroundColor: '#f5f5f7', borderRadius: '4px', marginBottom: '12px' }} />
                    <div style={{ width: '70%', height: '16px', backgroundColor: '#f5f5f7', borderRadius: '4px', marginBottom: '12px' }} />
                 </div>
                 <div style={{ flex: 1, backgroundColor: '#fff', borderRadius: '12px', padding: '32px', boxShadow: '0 4px 12px rgba(0,0,0,0.05)' }}>
                    <div style={{ width: '40%', height: '32px', backgroundColor: '#f5f5f7', borderRadius: '8px', marginBottom: '24px' }} />
                    <div style={{ display: 'flex', gap: '16px', marginBottom: '24px' }}>
                      <div style={{ flex: 1, height: '120px', backgroundColor: 'rgba(0,102,204,0.05)', borderRadius: '12px', border: '1px solid rgba(0,102,204,0.1)' }} />
                      <div style={{ flex: 1, height: '120px', backgroundColor: '#f5f5f7', borderRadius: '12px' }} />
                      <div style={{ flex: 1, height: '120px', backgroundColor: '#f5f5f7', borderRadius: '12px' }} />
                    </div>
                    <div style={{ width: '100%', height: '200px', backgroundColor: '#f5f5f7', borderRadius: '12px' }} />
                 </div>
               </div>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Features */}
      <section style={{ padding: '100px 0', backgroundColor: '#f5f5f7' }}>
        <div className="container">
          <div style={{ display: 'flex', gap: '32px' }}>
            {[
              { icon: <Sparkles size={32} color="#0066cc" />, title: 'Diseño Premium', desc: 'Una interfaz diseñada obsesivamente para la mejor experiencia de usuario.' },
              { icon: <Zap size={32} color="#0066cc" />, title: 'Rápido y Fluido', desc: 'Navegación instantánea y animaciones naturales que se sienten nativas.' },
              { icon: <ShieldCheck size={32} color="#0066cc" />, title: 'Empresas Validadas', desc: 'Un entorno seguro con ofertas reales y empresas verificadas.' }
            ].map((f, i) => (
              <motion.div 
                key={i}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.5, delay: i * 0.1 }}
                style={{ flex: 1, backgroundColor: '#fff', padding: '40px', borderRadius: '24px', boxShadow: '0 8px 32px rgba(0,0,0,0.04)' }}
                className="hover-lift"
              >
                <div style={{ marginBottom: '20px' }}>{f.icon}</div>
                <h3 style={{ fontSize: '24px', marginBottom: '12px' }}>{f.title}</h3>
                <p style={{ color: '#86868b', fontSize: '16px', lineHeight: 1.5 }}>{f.desc}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
};

export default Landing;
