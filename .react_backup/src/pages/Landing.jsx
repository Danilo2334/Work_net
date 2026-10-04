import React from 'react';
import { motion } from 'framer-motion';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowRight, Sparkles, ShieldCheck, Zap, Search, MapPin, Search as SearchIcon, ArrowUpRight, CheckCircle2 } from 'lucide-react';
import BrandLogo from '../components/common/BrandLogo';
import ThemeToggle from '../components/common/ThemeToggle';
import { Reveal, Stagger, StaggerItem } from '../motion/Reveal';
import Card from '../components/common/Card';
import Pressable from '../motion/Pressable';
import ShaderBackground from '../components/common/ShaderBackground';

const Landing = () => {
  const navigate = useNavigate();

  return (
    <div style={{ minHeight: '100vh', backgroundColor: 'var(--bg-color)', color: 'var(--text-primary)', position: 'relative' }}>
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: '900px', zIndex: 0, opacity: 0.6, pointerEvents: 'none' }}>
        <ShaderBackground />
      </div>

      <div style={{ position: 'relative', zIndex: 1 }}>
        {/* Navigation */}
        <nav className="glass-nav" style={{ padding: '20px 0' }}>
          <div className="container" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '48px' }}>
              <BrandLogo />
              <div style={{ display: 'flex', gap: '32px', alignItems: 'center' }} className="nav-links">
                <Link to="/candidate" style={{ fontWeight: 500, color: 'var(--text-secondary)', textDecoration: 'none', transition: 'var(--motion-spring-base)' }}>Candidatos</Link>
                <Link to="/company" style={{ fontWeight: 500, color: 'var(--text-secondary)', textDecoration: 'none', transition: 'var(--motion-spring-base)' }}>Empresas</Link>
                <a href="#precios" style={{ fontWeight: 500, color: 'var(--text-secondary)', textDecoration: 'none', transition: 'var(--motion-spring-base)' }}>Precios</a>
              </div>
            </div>
            <div style={{ display: 'flex', gap: '24px', alignItems: 'center' }}>
              <ThemeToggle />
              <Link to="/login" style={{ fontWeight: 500, color: 'var(--text-primary)', textDecoration: 'none', transition: 'var(--motion-spring-base)' }}>
                Iniciar Sesión
              </Link>
              <Pressable 
                onClick={() => navigate('/register')}
                style={{ backgroundColor: 'var(--primary-blue)', color: '#fff', padding: '10px 24px', borderRadius: '980px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}
              >
                Registrarse
              </Pressable>
            </div>
          </div>
        </nav>

        {/* Hero Section */}
        <section style={{ padding: '80px 0 60px', textAlign: 'center' }}>
          <div className="container" style={{ maxWidth: '900px' }}>
            <Reveal>
              <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', padding: '6px 16px', backgroundColor: 'var(--surface-color)', border: '1px solid var(--border-color)', borderRadius: '980px', marginBottom: '32px', fontSize: '13px', fontWeight: 600, color: 'var(--primary-blue)' }}>
                <span style={{ display: 'inline-block', width: '20px', height: '20px', backgroundColor: 'rgba(0, 102, 204, 0.1)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Sparkles size={12} />
                </span>
                La nueva era del reclutamiento inteligente <ArrowRight size={14} style={{ color: 'var(--text-secondary)' }} />
              </div>

              <h1 style={{ fontSize: '72px', fontWeight: 800, letterSpacing: '-0.04em', lineHeight: 1.1, marginBottom: '24px' }}>
                El futuro del <span style={{ color: 'var(--primary-blue)' }}>reclutamiento</span>.<br /> Simple. Inteligente.
              </h1>
              
              <p style={{ fontSize: '20px', color: 'var(--text-secondary)', maxWidth: '640px', margin: '0 auto 40px', fontWeight: 400, lineHeight: 1.5 }}>
                Conecta talento excepcional con las mejores empresas usando una plataforma impulsada por IA diseñada para la excelencia, precisión y máxima velocidad.
              </p>

              <div style={{ display: 'flex', justifyContent: 'center', gap: '16px', marginBottom: '48px' }}>
                <Pressable 
                  onClick={() => navigate('/candidate')}
                  style={{ backgroundColor: 'var(--primary-blue)', color: '#fff', borderRadius: '980px', fontSize: '16px', fontWeight: 600, padding: '16px 32px', display: 'flex', alignItems: 'center', gap: '8px', boxShadow: '0 8px 24px rgba(0, 102, 204, 0.3)' }}
                >
                  Soy Candidato <ArrowRight size={18} />
                </Pressable>
                <Pressable 
                  onClick={() => navigate('/company')}
                  style={{ backgroundColor: 'var(--surface-color)', color: 'var(--text-primary)', border: '1px solid var(--border-color)', borderRadius: '980px', fontSize: '16px', fontWeight: 600, padding: '16px 32px', display: 'flex', alignItems: 'center', gap: '8px' }}
                >
                  Soy Empresa
                </Pressable>
              </div>

              <div style={{ display: 'flex', justifyContent: 'center', gap: '32px', fontSize: '12px', fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}><div style={{ width: 6, height: 6, borderRadius: '50%', backgroundColor: '#10b981' }} /> +18,000 vacantes activas</span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}><div style={{ width: 6, height: 6, borderRadius: '50%', backgroundColor: 'var(--primary-blue)' }} /> 94% tasa de match IA</span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}><div style={{ width: 6, height: 6, borderRadius: '50%', backgroundColor: '#8b5cf6' }} /> +2,000 empresas líderes</span>
              </div>
            </Reveal>

            {/* Search Bar */}
            <Reveal delay={0.2}>
              <div style={{ marginTop: '48px', backgroundColor: 'var(--surface-color)', padding: '8px', borderRadius: '24px', border: '1px solid var(--border-color)', display: 'flex', boxShadow: '0 24px 48px rgba(0,0,0,0.05)', maxWidth: '900px', margin: '48px auto 0' }}>
                <div style={{ flex: 1, display: 'flex', alignItems: 'center', padding: '0 24px', borderRight: '1px solid var(--border-color)' }}>
                  <Search size={20} color="var(--text-secondary)" style={{ marginRight: '12px' }} />
                  <input type="text" placeholder="Cargo, habilidad o palabra clave (ej. React)" style={{ width: '100%', border: 'none', background: 'transparent', outline: 'none', fontSize: '16px', color: 'var(--text-primary)' }} />
                </div>
                <div style={{ flex: 1, display: 'flex', alignItems: 'center', padding: '0 24px' }}>
                  <MapPin size={20} color="var(--text-secondary)" style={{ marginRight: '12px' }} />
                  <input type="text" placeholder="Ubicación o Remoto (ej. México, España)" style={{ width: '100%', border: 'none', background: 'transparent', outline: 'none', fontSize: '16px', color: 'var(--text-primary)' }} />
                </div>
                <Pressable style={{ backgroundColor: '#0f172a', color: '#fff', padding: '16px 32px', borderRadius: '16px', fontSize: '16px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}>
                  Explorar empleos <ArrowUpRight size={18} />
                </Pressable>
              </div>
            </Reveal>
          </div>
        </section>

        {/* Features */}
        <section style={{ padding: '60px 0', backgroundColor: 'transparent' }}>
          <div className="container">
            <Stagger staggerChildren={0.15} style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '24px' }}>
              {[
                { icon: <Sparkles size={24} color="var(--primary-blue)" />, title: 'Diseño Premium', desc: 'Una interfaz diseñada obsesivamente para la mejor experiencia de usuario y máxima productividad diaria.' },
                { icon: <Zap size={24} color="var(--primary-blue)" />, title: 'Rápido y Fluido', desc: 'Navegación instantánea y transiciones naturales que se sienten nativas en cada interacción y postulación.' },
                { icon: <ShieldCheck size={24} color="var(--primary-blue)" />, title: 'Empresas Validadas', desc: 'Un entorno seguro con ofertas reales, salarios transparentes y empresas verificadas rigurosamente.' }
              ].map((f, i) => (
                <StaggerItem key={i}>
                  <Card hoverable className="glass-panel" style={{ padding: '40px', borderRadius: '24px', backgroundColor: 'var(--surface-color)', cursor: 'default', height: '100%', textAlign: 'left' }}>
                    <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'rgba(0, 102, 204, 0.05)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '24px' }}>
                      {f.icon}
                    </div>
                    <h3 style={{ fontSize: '20px', marginBottom: '12px', fontWeight: 700 }}>{f.title}</h3>
                    <p style={{ color: 'var(--text-secondary)', fontSize: '15px', lineHeight: 1.6 }}>{f.desc}</p>
                  </Card>
                </StaggerItem>
              ))}
            </Stagger>
          </div>
        </section>

        {/* Logos */}
        <section style={{ padding: '60px 0', textAlign: 'center' }}>
          <div className="container">
            <p style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '40px' }}>Equipos de tecnología de clase mundial reclutan en WorkNet</p>
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '48px', flexWrap: 'wrap', opacity: 0.6, filter: 'grayscale(100%)' }}>
              <div style={{ fontSize: '20px', fontWeight: 700 }}>Mercado Libre</div>
              <div style={{ fontSize: '20px', fontWeight: 700 }}>Nubank</div>
              <div style={{ fontSize: '20px', fontWeight: 700 }}>Rappi</div>
              <div style={{ fontSize: '20px', fontWeight: 700 }}>Globant</div>
              <div style={{ fontSize: '20px', fontWeight: 700 }}>Kavak</div>
            </div>
          </div>
        </section>

        {/* CTA 1 (Blue Tint) */}
        <section style={{ padding: '80px 0' }}>
          <div className="container">
            <Reveal>
              <div style={{ backgroundColor: 'rgba(0, 102, 204, 0.05)', borderRadius: '32px', padding: '64px', display: 'flex', gap: '64px', alignItems: 'center', border: '1px solid rgba(0, 102, 204, 0.1)' }}>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', padding: '4px 12px', backgroundColor: 'var(--surface-color)', borderRadius: '980px', marginBottom: '24px', fontSize: '12px', fontWeight: 600, color: 'var(--primary-blue)', border: '1px solid var(--border-color)' }}>
                    <div style={{ width: 6, height: 6, borderRadius: '50%', backgroundColor: 'var(--primary-blue)' }} /> Algoritmo Neuronal de Compatibilidad v4.2
                  </div>
                  <h2 style={{ fontSize: '40px', fontWeight: 700, marginBottom: '24px', lineHeight: 1.2 }}>Descubre oportunidades diseñadas para tu perfil exacto</h2>
                  <p style={{ fontSize: '18px', color: 'var(--text-secondary)', marginBottom: '40px', lineHeight: 1.6 }}>
                    Nuestra inteligencia de correspondencia evalúa habilidades tangibles, stack tecnológico y cultura de trabajo para garantizar un 94% de éxito en la primera entrevista.
                  </p>
                  <div style={{ display: 'flex', gap: '24px' }}>
                    <div style={{ backgroundColor: 'var(--surface-color)', padding: '24px', borderRadius: '16px', flex: 1, border: '1px solid var(--border-color)' }}>
                      <div style={{ fontSize: '32px', fontWeight: 800, color: 'var(--primary-blue)', marginBottom: '8px' }}>4.8x</div>
                      <div style={{ fontSize: '14px', color: 'var(--text-secondary)', fontWeight: 500 }}>Más rápido en contratación</div>
                    </div>
                    <div style={{ backgroundColor: 'var(--surface-color)', padding: '24px', borderRadius: '16px', flex: 1, border: '1px solid var(--border-color)' }}>
                      <div style={{ fontSize: '32px', fontWeight: 800, color: '#10b981', marginBottom: '8px' }}>100%</div>
                      <div style={{ fontSize: '14px', color: 'var(--text-secondary)', fontWeight: 500 }}>Salarios transparentes</div>
                    </div>
                    <div style={{ backgroundColor: 'var(--surface-color)', padding: '24px', borderRadius: '16px', flex: 1, border: '1px solid var(--border-color)' }}>
                      <div style={{ fontSize: '32px', fontWeight: 800, color: '#8b5cf6', marginBottom: '8px' }}>0 spam</div>
                      <div style={{ fontSize: '14px', color: 'var(--text-secondary)', fontWeight: 500 }}>Reclutadores filtrados</div>
                    </div>
                  </div>
                </div>
                
                <div style={{ flex: 1 }}>
                  <Card className="glass-panel" style={{ padding: '32px', borderRadius: '24px', backgroundColor: 'var(--surface-color)', boxShadow: '0 24px 48px rgba(0,0,0,0.1)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '24px' }}>
                      <div style={{ width: '48px', height: '48px', borderRadius: '50%', backgroundColor: 'rgba(0,102,204,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, color: 'var(--primary-blue)' }}>
                        AS
                      </div>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontWeight: 700, fontSize: '16px' }}>Alex Saldaña</div>
                        <div style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>Staff Software Engineer</div>
                      </div>
                      <div style={{ backgroundColor: '#10b981', color: '#fff', padding: '6px 12px', borderRadius: '980px', fontSize: '12px', fontWeight: 700 }}>
                        98% Match
                      </div>
                    </div>
                    <div style={{ backgroundColor: 'rgba(0,102,204,0.05)', padding: '20px', borderRadius: '16px', marginBottom: '24px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '12px', fontSize: '13px', fontWeight: 600 }}>
                        <span>Alineación de habilidades</span>
                        <span style={{ color: 'var(--primary-blue)' }}>Excelente</span>
                      </div>
                      <div style={{ height: '8px', backgroundColor: 'var(--surface-color)', borderRadius: '4px', overflow: 'hidden' }}>
                        <div style={{ width: '94%', height: '100%', backgroundColor: 'var(--primary-blue)' }} />
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: '8px', marginBottom: '24px', flexWrap: 'wrap' }}>
                      <span style={{ padding: '6px 12px', backgroundColor: 'var(--bg-color)', border: '1px solid var(--border-color)', borderRadius: '6px', fontSize: '12px', fontWeight: 500 }}>React & Next.js</span>
                      <span style={{ padding: '6px 12px', backgroundColor: 'var(--bg-color)', border: '1px solid var(--border-color)', borderRadius: '6px', fontSize: '12px', fontWeight: 500 }}>Distributed Systems</span>
                      <span style={{ padding: '6px 12px', backgroundColor: 'var(--bg-color)', border: '1px solid var(--border-color)', borderRadius: '6px', fontSize: '12px', fontWeight: 500 }}>Remote Global</span>
                    </div>
                    <Pressable style={{ width: '100%', padding: '16px', backgroundColor: 'var(--primary-blue)', color: '#fff', borderRadius: '12px', fontWeight: 600, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px' }}>
                      <Zap size={16} /> Invitar a Entrevista Directa
                    </Pressable>
                  </Card>
                </div>
              </div>
            </Reveal>
          </div>
        </section>

        {/* Bottom CTA */}
        <section style={{ padding: '40px 0 80px' }}>
          <div className="container">
            <Reveal>
              <div style={{ backgroundColor: 'var(--surface-color)', borderRadius: '32px', padding: '80px 40px', textAlign: 'center', border: '1px solid var(--border-color)' }}>
                <h2 style={{ fontSize: '48px', fontWeight: 700, marginBottom: '24px', maxWidth: '600px', margin: '0 auto 24px', lineHeight: 1.1 }}>
                  ¿Listo para transformar la forma en que construyes tu equipo?
                </h2>
                <p style={{ color: 'var(--text-secondary)', fontSize: '18px', marginBottom: '40px' }}>
                  Crea tu cuenta gratuita hoy en menos de 2 minutos. Sin contratos forzosos ni configuraciones complejas.
                </p>
                <div style={{ display: 'flex', justifyContent: 'center', gap: '16px' }}>
                  <Pressable 
                    onClick={() => navigate('/register')}
                    style={{ backgroundColor: 'var(--primary-blue)', color: '#fff', borderRadius: '980px', fontSize: '16px', fontWeight: 600, padding: '16px 32px', display: 'flex', alignItems: 'center', gap: '8px' }}
                  >
                    Comenzar Ahora Gratis <ArrowRight size={18} />
                  </Pressable>
                  <Pressable style={{ backgroundColor: 'var(--bg-color)', color: 'var(--text-primary)', border: '1px solid var(--border-color)', borderRadius: '980px', fontSize: '16px', fontWeight: 600, padding: '16px 32px' }}>
                    Ver Comparativa de Planes
                  </Pressable>
                </div>
              </div>
            </Reveal>
          </div>
        </section>
      </div>

      {/* Footer */}
      <footer style={{ borderTop: '1px solid var(--border-color)', backgroundColor: 'var(--bg-color)', padding: '40px 0', marginTop: 'auto', position: 'relative', zIndex: 1 }}>
        <div className="container" style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '32px' }}>
            <div style={{ maxWidth: '300px' }}>
              <BrandLogo />
              <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '16px', lineHeight: 1.5 }}>
                Infraestructura moderna de reclutamiento y adquisición de talento de escala global, diseñada para equipos de alto rendimiento.
              </p>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '24px', fontSize: '12px', fontWeight: 500, color: 'var(--text-secondary)' }}>
                <div style={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: '#10b981' }} /> Todos los sistemas operativos
              </div>
            </div>
            
            <div style={{ display: 'flex', gap: '80px', flexWrap: 'wrap' }}>
              <div>
                <h4 style={{ fontSize: '14px', fontWeight: 700, marginBottom: '20px', color: 'var(--text-primary)' }}>Plataforma</h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <Link to="/candidate" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Bolsa de Empleo</Link>
                  <Link to="/company" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Gestión de Candidatos</Link>
                  <a href="#" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Planes Empresariales</a>
                </div>
              </div>
              
              <div>
                <h4 style={{ fontSize: '14px', fontWeight: 700, marginBottom: '20px', color: 'var(--text-primary)' }}>Compañía</h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <a href="#" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Acerca de</a>
                  <a href="#" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Seguridad</a>
                  <a href="#" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Contacto</a>
                </div>
              </div>

              <div>
                <h4 style={{ fontSize: '14px', fontWeight: 700, marginBottom: '20px', color: 'var(--text-primary)' }}>Legal</h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <a href="#" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Privacidad</a>
                  <a href="#" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Términos</a>
                  <a href="#" style={{ color: 'var(--text-secondary)', fontSize: '14px', textDecoration: 'none' }}>Cumplimiento SOC2</a>
                </div>
              </div>
            </div>
          </div>
          
          <div style={{ paddingTop: '32px', borderTop: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
            <p style={{ color: 'var(--text-secondary)', fontSize: '12px', margin: 0 }}>
              &copy; {new Date().getFullYear()} WorkNet Technologies Inc. Todos los derechos reservados.
            </p>
            <div style={{ color: 'var(--text-secondary)', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <ShieldCheck size={14} /> Encriptación de 256 bits
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default Landing;
