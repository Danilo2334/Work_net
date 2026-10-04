/**
 * Minimal observable base class.
 * Shared by stateful services (theme, session) so that they can be consumed
 * from React through `useSyncExternalStore` without duplicating listener logic.
 */
export class Observable {
  #listeners = new Set();

  /**
   * Registers a listener and returns its unsubscribe function.
   * Arrow function so it can be passed directly to `useSyncExternalStore`.
   */
  subscribe = (listener) => {
    this.#listeners.add(listener);
    return () => this.#listeners.delete(listener);
  };

  notify() {
    this.#listeners.forEach((listener) => listener());
  }
}
