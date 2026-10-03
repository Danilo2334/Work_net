import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import AuthLayout from '../components/auth/AuthLayout';
import FormField from '../components/common/FormField';
import Pressable from '../motion/Pressable';

const LOGIN_ROLES = [
  { role: 'candidate', label: 'Entrar como Candidato', className: 'btn-primary' },
  { role: 'company', label: 'Entrar como Empresa', className: 'btn-inverse' },
  { role: 'admin', label: 'Entrar como Admin', className: 'btn-outline' },
];

const Login = () => {
  const navigate = useNavigate();

  const handleLogin = (e, role) => {
    e.preventDefault();
    navigate(`/${role}`);
  };

  return (
    <AuthLayout
      title="Bienvenido de nuevo"
      subtitle="Inicia sesión para continuar en WorkNet."
      panelTitle="Donde el talento encuentra su lugar."
      panelText="Únete a miles de profesionales y empresas que ya están transformando su futuro con WorkNet."
      footer={
        <>
          ¿No tienes cuenta? <Link to="/register">Regístrate</Link>
        </>
      }
    >
      <form className="glass-panel auth__form">
        <FormField id="login-email" label="Correo electrónico" type="email" placeholder="nombre@ejemplo.com" autoComplete="email" />
        <FormField id="login-password" label="Contraseña" type="password" placeholder="••••••••" autoComplete="current-password" />

        <div className="auth__row">
          <label className="auth__checkbox">
            <input type="checkbox" /> Recordarme
          </label>
          <a href="#" className="auth__link">¿Olvidaste tu contraseña?</a>
        </div>

        <div className="auth__actions">
          {LOGIN_ROLES.map(({ role, label, className }) => (
            <Pressable
              key={role}
              id={`login-${role}`}
              type="button"
              className={`btn btn-lg btn-block ${className}`}
              style={{ borderRadius: 12 }}
              onClick={(e) => handleLogin(e, role)}
            >
              {label}
            </Pressable>
          ))}
        </div>
      </form>
    </AuthLayout>
  );
};

export default Login;
