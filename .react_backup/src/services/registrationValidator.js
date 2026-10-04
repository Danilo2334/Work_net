import { getRole } from '../config/roles';

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
export const MIN_PASSWORD_LENGTH = 8;

/**
 * Pure validation for the registration form.
 * @returns {Record<string, string>} field → error message (empty when valid)
 */
export function validateRegistration({ name, email, password, role, headline }) {
  const errors = {};

  if (!name?.trim() || name.trim().length < 2) errors.name = 'Introduce tu nombre completo.';
  if (!EMAIL_PATTERN.test(email?.trim() ?? '')) errors.email = 'Introduce un correo válido.';
  if ((password ?? '').length < MIN_PASSWORD_LENGTH) {
    errors.password = `La contraseña debe tener al menos ${MIN_PASSWORD_LENGTH} caracteres.`;
  }
  if (!getRole(role)) errors.role = 'Selecciona un tipo de cuenta.';
  if (role === 'company' && !headline?.trim()) errors.headline = 'Indica el nombre de la empresa.';

  return errors;
}
