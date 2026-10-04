import { getRole } from '../config/roles';

/**
 * Derived account data for dashboards (pure functions, easy to extend/test).
 */
export function getProfileCompletion(user) {
  const checklist = getRole(user?.role)?.profileChecklist ?? [];
  const items = checklist.map((item) => ({ ...item, done: Boolean(user?.[item.key]) }));
  const completed = items.filter((item) => item.done).length;
  const percent = items.length ? Math.round((completed / items.length) * 100) : 0;
  return { items, completed, total: items.length, percent };
}

export const getFirstName = (name = '') => name.trim().split(/\s+/)[0] ?? '';

const dateFormatter = new Intl.DateTimeFormat('es', { day: 'numeric', month: 'long', year: 'numeric' });
const todayFormatter = new Intl.DateTimeFormat('es', { weekday: 'long', day: 'numeric', month: 'long' });

export const formatDate = (iso) => {
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? '—' : dateFormatter.format(date);
};

export const formatToday = () => {
  const text = todayFormatter.format(new Date());
  return text.charAt(0).toUpperCase() + text.slice(1);
};

export const getGreeting = (date = new Date()) => {
  const hour = date.getHours();
  if (hour < 12) return 'Buenos días';
  if (hour < 20) return 'Buenas tardes';
  return 'Buenas noches';
};
