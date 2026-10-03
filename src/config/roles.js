import {
  Briefcase,
  Building2,
  CheckCircle,
  FileText,
  Home,
  LayoutDashboard,
  Search,
  ShieldCheck,
  Upload,
  UserRound,
  Users,
} from 'lucide-react';

/**
 * Single source of truth for role-specific metadata.
 * Navigation items keep the exact same paths/labels the Sidebar had before;
 * welcome-dashboard content (next steps, profile checklist) lives here too so
 * new roles or steps can be added without touching components.
 */
export const ROLES = Object.freeze({
  candidate: {
    id: 'candidate',
    label: 'Candidato',
    icon: UserRound,
    homePath: '/candidate',
    headlineLabel: 'Cargo o profesión',
    headlinePlaceholder: 'Ej. Diseñador de producto',
    nav: [
      { path: '/candidate', icon: LayoutDashboard, label: 'Dashboard' },
      { path: '/candidate/jobs', icon: Briefcase, label: 'Búsqueda de Ofertas' },
      { path: '/candidate/applications', icon: FileText, label: 'Postulaciones' },
      { path: '/candidate/profile', icon: Users, label: 'Perfil y CV' },
    ],
    accountStatus: { label: 'Activa', tone: 'green', hint: 'Ya puedes postularte a ofertas.' },
    profileChecklist: [
      { key: 'name', label: 'Nombre' },
      { key: 'email', label: 'Correo' },
      { key: 'headline', label: 'Cargo' },
      { key: 'avatar', label: 'Foto de perfil' },
      { key: 'cv', label: 'Currículum' },
    ],
    nextSteps: [
      { id: 'profile', icon: UserRound, title: 'Completa tu perfil', description: 'Añade experiencia y habilidades para destacar.', path: '/candidate/profile' },
      { id: 'cv', icon: Upload, title: 'Sube tu CV', description: 'Las empresas verán tu currículum al postularte.', path: '/candidate/profile' },
      { id: 'jobs', icon: Search, title: 'Explora ofertas', description: 'Encuentra roles que encajen contigo.', path: '/candidate/jobs' },
    ],
  },
  company: {
    id: 'company',
    label: 'Empresa',
    icon: Building2,
    homePath: '/company',
    headlineLabel: 'Nombre de la empresa',
    headlinePlaceholder: 'Ej. TechCorp Solutions',
    nav: [
      { path: '/company', icon: LayoutDashboard, label: 'Dashboard' },
      { path: '/company/jobs', icon: Briefcase, label: 'Mis Ofertas' },
      { path: '/company/candidates', icon: Users, label: 'Candidatos' },
    ],
    accountStatus: { label: 'En verificación', tone: 'amber', hint: 'Un administrador validará tu empresa.' },
    profileChecklist: [
      { key: 'name', label: 'Responsable' },
      { key: 'email', label: 'Correo' },
      { key: 'headline', label: 'Empresa' },
      { key: 'logo', label: 'Logo' },
      { key: 'description', label: 'Descripción' },
    ],
    nextSteps: [
      { id: 'profile', icon: Building2, title: 'Perfil de empresa', description: 'Cuenta a los candidatos quiénes sois.', path: '/company' },
      { id: 'verify', icon: ShieldCheck, title: 'Verificación', description: 'Tu empresa está en revisión por el equipo de WorkNet.', path: '/company' },
      { id: 'job', icon: Briefcase, title: 'Publica tu primera oferta', description: 'Empieza a recibir candidatos cualificados.', path: '/company/jobs' },
    ],
  },
  admin: {
    id: 'admin',
    label: 'Administrador',
    icon: ShieldCheck,
    homePath: '/admin',
    nav: [
      { path: '/admin', icon: LayoutDashboard, label: 'Dashboard' },
      { path: '/admin/companies', icon: CheckCircle, label: 'Validar Empresas' },
      { path: '/admin/users', icon: Users, label: 'Usuarios' },
    ],
  },
});

/** Roles that can self-register. */
export const REGISTRABLE_ROLES = [ROLES.candidate, ROLES.company];

/** Entry shown first in the sidebar for registered users. */
export const WELCOME_NAV_ITEM = { path: '/welcome', icon: Home, label: 'Inicio' };

export const getRole = (roleId) => ROLES[roleId] ?? null;
