/**
 * Thin wrapper around Web Storage that never throws
 * (private mode, disabled storage, quota errors or malformed JSON).
 */
export class SafeStorage {
  #storage;

  constructor(storage) {
    this.#storage = storage ?? SafeStorage.#resolveDefault();
  }

  static #resolveDefault() {
    try {
      return typeof window !== 'undefined' ? window.localStorage : null;
    } catch {
      return null;
    }
  }

  get(key) {
    try {
      return this.#storage?.getItem(key) ?? null;
    } catch {
      return null;
    }
  }

  set(key, value) {
    try {
      this.#storage?.setItem(key, value);
    } catch {
      /* storage unavailable: preference simply won't persist */
    }
  }

  remove(key) {
    try {
      this.#storage?.removeItem(key);
    } catch {
      /* noop */
    }
  }

  getJSON(key) {
    const raw = this.get(key);
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch {
      return null;
    }
  }

  setJSON(key, value) {
    this.set(key, JSON.stringify(value));
  }
}
