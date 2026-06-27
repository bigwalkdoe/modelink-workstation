import type { OSState } from '@/types';

export function handleAuthAction(state: OSState, action: any): Partial<OSState> {
  switch (action.type) {
    case 'SET_BOOT_PHASE': {
      return { bootPhase: action.phase };
    }
    case 'LOGIN': {
      return {
        auth: { isAuthenticated: true, isGuest: action.isGuest, userName: action.isGuest ? 'Guest' : 'User' },
        bootPhase: 'desktop' as const,
      };
    }
    case 'LOGOUT': {
      return {
        auth: { isAuthenticated: false, isGuest: false, userName: 'User' },
        windows: [],
        bootPhase: 'login' as const,
        activeWindowId: null,
      };
    }
    default:
      return {};
  }
}
