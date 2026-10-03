import { Observable } from '../lib/Observable';
import { SafeStorage } from '../lib/SafeStorage';
import { REGISTRABLE_ROLES, getRole } from '../config/roles';

const SESSION_KEY = 'worknet-session';

/**
 * Client-side session for registered users (no backend yet).
 * Only non-sensitive profile data is stored – passwords are never persisted.
 * Swap the storage layer for real API calls when a backend exists; the
 * public API (getUser / register / logout / subscribe) can stay the same.
 */
export class SessionService extends Observable {
  #storage;
  #user;

  constructor(storage = new SafeStorage()) {
    super();
    this.#storage = storage;
    this.#user = this.#load();
  }

  /** Cached snapshot (stable reference for useSyncExternalStore). */
  getUser = () => this.#user;

  register({ name, email, role, headline }) {
    if (!REGISTRABLE_ROLES.some((r) => r.id === role)) {
      throw new Error(`Rol no permitido: ${role}`);
    }
    const user = Object.freeze({
      id: SessionService.#createId(),
      name: name.trim(),
      email: email.trim().toLowerCase(),
      role,
      headline: headline?.trim() ?? '',
      createdAt: new Date().toISOString(),
    });
    this.#storage.setJSON(SESSION_KEY, user);
    this.#user = user;
    this.notify();
    return user;
  }

  logout() {
    if (!this.#user) return;
    this.#storage.remove(SESSION_KEY);
    this.#user = null;
    this.notify();
  }

  #load() {
    const data = this.#storage.getJSON(SESSION_KEY);
    const isValid = data && typeof data.name === 'string' && typeof data.email === 'string' && getRole(data.role);
    return isValid ? Object.freeze(data) : null;
  }

  static #createId() {
    return globalThis.crypto?.randomUUID?.() ?? `u_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
  }
}

export const sessionService = new SessionService();
