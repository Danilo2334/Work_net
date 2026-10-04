import { useSyncExternalStore } from 'react';
import { sessionService } from './SessionService';

/** Current registered user (or null) – re-renders on register / logout. */
export function useSession() {
  const user = useSyncExternalStore(sessionService.subscribe, sessionService.getUser);
  return {
    user,
    register: (data) => sessionService.register(data),
    logout: () => sessionService.logout(),
  };
}
