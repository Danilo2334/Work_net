import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import AuthLayout from '../components/auth/AuthLayout';
import FormField from '../components/common/FormField';
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
      // In a real app, password is authenticated, but here we just register local session
      sessionService.register({
        name: formData.name,
        email: formData.email,
        role: role,
        headline: role === 'candidate' ? 'Profesional en búsqueda de oportunidades' : 'Empresa buscando talento'
      });
      // Redirect to the new welcome dashboard
      navigate('/welcome');
    } catch (err) {
      console.error('Error during registration:', err);
    }
  };

  return (
    <AuthLayout
      title="Crea tu cuenta"
      subtitle="Únete a la plataforma líder para talento y empresas."
      panelTitle="El futuro del trabajo."
      panelText="Conecta con las mejores oportunidades o encuentra al candidato ideal de forma inteligente y sencilla."
      footer={
        <>
          ¿Ya tienes cuenta? <Link to="/login">Inicia sesión</Link>
        </>
      }
    >
      <form className="glass-panel auth__form" onSubmit={handleSubmit}>
        <div style={{ display: 'flex', gap: '8px', marginBottom: '24px' }}>
          <Pressable
            type="button"
            className={`btn btn-block ${role === 'candidate' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setRole('candidate')}
            style={{ borderRadius: 12, flex: 1 }}
          >
            Soy Candidato
          </Pressable>
          <Pressable
            type="button"
            className={`btn btn-block ${role === 'company' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setRole('company')}
            style={{ borderRadius: 12, flex: 1 }}
          >
            Soy Empresa
          </Pressable>
        </div>

        <FormField 
          id="register-name" 
          name="name"
          label={role === 'candidate' ? "Nombre completo" : "Nombre de la empresa"}
          type="text" 
          placeholder={role === 'candidate' ? "Juan Pérez" : "Tech Corp"}
          value={formData.name}
          onChange={handleChange}
          required
        />
        <FormField 
          id="register-email" 
          name="email"
          label="Correo electrónico" 
          type="email" 
          placeholder="nombre@ejemplo.com"
          value={formData.email}
          onChange={handleChange}
          required
        />
        <FormField 
          id="register-password" 
          name="password"
          label="Contraseña" 
          type="password" 
          placeholder="••••••••"
          value={formData.password}
          onChange={handleChange}
          required
        />

        <div className="auth__actions" style={{ marginTop: '32px' }}>
          <Pressable
            type="submit"
            className="btn btn-primary btn-lg btn-block"
            style={{ borderRadius: 12 }}
          >
            Registrarme
          </Pressable>
        </div>
      </form>
    </AuthLayout>
  );
};

export default Register;
