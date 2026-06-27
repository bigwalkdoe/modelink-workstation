import React, { createContext, useContext, useReducer, useCallback } from 'react';
import type { OSState, OSAction, DesktopIcon, DockItem, Notification } from '@/types';
import { APP_REGISTRY, getDefaultDockApps } from '@/apps/registry';
import { handleWindowAction, type WindowActionPatch } from '@/reducers/windows';
import { handleUIAction } from '@/reducers/ui';
import { handleAuthAction } from '@/reducers/auth';

const defaultDesktopIcons: DesktopIcon[] = [
  { id: 'desk-home', name: 'Home', icon: 'Home', appId: 'filemanager', position: { x: 16, y: 16 }, isSelected: false },
  { id: 'desk-trash', name: 'Trash', icon: 'Trash2', appId: 'filemanager', position: { x: 16, y: 106 }, isSelected: false },
  { id: 'desk-text', name: 'Text Editor', icon: 'FileText', appId: 'texteditor', position: { x: 16, y: 196 }, isSelected: false },
  { id: 'desk-terminal', name: 'Terminal', icon: 'Terminal', appId: 'terminal', position: { x: 16, y: 286 }, isSelected: false },
  { id: 'desk-settings', name: 'Settings', icon: 'Settings', appId: 'settings', position: { x: 96, y: 16 }, isSelected: false },
  { id: 'desk-browser', name: 'Web Browser', icon: 'Globe', appId: 'browser', position: { x: 96, y: 106 }, isSelected: false },
  { id: 'desk-calendar', name: 'Calendar', icon: 'Calendar', appId: 'calendar', position: { x: 96, y: 196 }, isSelected: false },
];

const createInitialDockItems = (): DockItem[] => {
  const pinned = getDefaultDockApps();
  return APP_REGISTRY.map((app) => ({
    appId: app.id,
    isPinned: pinned.includes(app.id),
    isOpen: false,
    isFocused: false,
    bounce: false,
  }));
};

const loadDesktopIcons = (): DesktopIcon[] => {
  try {
    const saved = localStorage.getItem('ubuntuos_desktop_icons');
    if (saved) return JSON.parse(saved) as DesktopIcon[];
  } catch { /* ignore */ }
  return defaultDesktopIcons;
};

const initialState: OSState = {
  bootPhase: 'off',
  auth: { isAuthenticated: false, isGuest: false, userName: 'User' },
  windows: [],
  apps: APP_REGISTRY,
  desktopIcons: loadDesktopIcons(),
  theme: {
    mode: 'dark',
    accent: '#7C4DFF',
    wallpaper: '/wallpaper-default.jpg',
  },
  notifications: [],
  dockItems: createInitialDockItems(),
  contextMenu: {
    visible: false,
    x: 0,
    y: 0,
    type: 'desktop',
    items: [],
  },
  appLauncherOpen: false,
  notificationCenterOpen: false,
  activeWindowId: null,
  nextZIndex: 100,
  isAltTabbing: false,
  altTabIndex: 0,
};

function syncDockFromWindows(state: OSState, patch: WindowActionPatch): DockItem[] {
  const windows = patch.windows ?? state.windows;
  const dockMap = new Map<string, { isOpen: boolean; isFocused: boolean }>();
  for (const w of windows) {
    if (w.state === 'minimized') continue;
    const existing = dockMap.get(w.appId);
    dockMap.set(w.appId, {
      isOpen: true,
      isFocused: existing ? (existing.isFocused || w.isFocused) : w.isFocused,
    });
  }

  return state.dockItems.map((d) => ({
    ...d,
    isOpen: dockMap.has(d.appId) || d.isPinned,
    isFocused: dockMap.get(d.appId)?.isFocused ?? false,
    bounce: d.appId === patch.dockBounce ? true : d.bounce,
  }));
}

function osReducer(state: OSState, action: OSAction): OSState {
  const authPatch = handleAuthAction(state, action);
  if (Object.keys(authPatch).length > 0) {
    return { ...state, ...authPatch };
  }

  const windowPatch = handleWindowAction(state, action);
  if (Object.keys(windowPatch).length > 0) {
    const { dockBounce, ...rest } = windowPatch;
    return {
      ...state,
      ...rest,
      dockItems: syncDockFromWindows(state, windowPatch),
    };
  }

  const uiPatch = handleUIAction(state, action);
  if (Object.keys(uiPatch).length > 0) {
    return { ...state, ...uiPatch };
  }

  return state;
}

interface OSContextType {
  state: OSState;
  dispatch: React.Dispatch<OSAction>;
}

const OSContext = createContext<OSContextType | null>(null);

export const OSProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, dispatch] = useReducer(osReducer, initialState);
  return (
    <OSContext.Provider value={{ state, dispatch }}>
      {children}
    </OSContext.Provider>
  );
};

export const useOS = () => {
  const ctx = useContext(OSContext);
  if (!ctx) throw new Error('useOS must be used within OSProvider');
  return ctx;
};

export const useWindows = () => {
  const { state, dispatch } = useOS();
  return {
    windows: state.windows,
    openWindow: useCallback((appId: string, title?: string) => dispatch({ type: 'OPEN_WINDOW', appId, title }), [dispatch]),
    closeWindow: useCallback((windowId: string) => dispatch({ type: 'CLOSE_WINDOW', windowId }), [dispatch]),
    minimizeWindow: useCallback((windowId: string) => dispatch({ type: 'MINIMIZE_WINDOW', windowId }), [dispatch]),
    maximizeWindow: useCallback((windowId: string) => dispatch({ type: 'MAXIMIZE_WINDOW', windowId }), [dispatch]),
    restoreWindow: useCallback((windowId: string) => dispatch({ type: 'RESTORE_WINDOW', windowId }), [dispatch]),
    focusWindow: useCallback((windowId: string) => dispatch({ type: 'FOCUS_WINDOW', windowId }), [dispatch]),
    moveWindow: useCallback((windowId: string, position: { x: number; y: number }) => dispatch({ type: 'MOVE_WINDOW', windowId, position }), [dispatch]),
    resizeWindow: useCallback((windowId: string, size: { width: number; height: number }) => dispatch({ type: 'RESIZE_WINDOW', windowId, size }), [dispatch]),
    activeWindowId: state.activeWindowId,
  };
};

export const useNotifications = () => {
  const { state, dispatch } = useOS();
  return {
    notifications: state.notifications,
    addNotification: useCallback(
      (n: Omit<Notification, 'id' | 'timestamp'>) => dispatch({ type: 'ADD_NOTIFICATION', notification: n }),
      [dispatch]
    ),
    removeNotification: useCallback((id: string) => dispatch({ type: 'REMOVE_NOTIFICATION', id }), [dispatch]),
    clearNotifications: useCallback(() => dispatch({ type: 'CLEAR_NOTIFICATIONS' }), [dispatch]),
  };
};
