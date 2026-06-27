import type { OSState, DesktopIcon, ContextMenuType, ContextMenuItem, Notification } from '@/types';

const generateId = () => Math.random().toString(36).slice(2) + Date.now().toString(36);

export function handleUIAction(state: OSState, action: any): Partial<OSState> {
  switch (action.type) {
    case 'TOGGLE_APP_LAUNCHER': {
      return { appLauncherOpen: !state.appLauncherOpen };
    }
    case 'SET_APP_LAUNCHER': {
      return { appLauncherOpen: action.open };
    }

    case 'TOGGLE_NOTIFICATION_CENTER': {
      return { notificationCenterOpen: !state.notificationCenterOpen };
    }

    case 'ADD_NOTIFICATION': {
      const notif: Notification = {
        ...action.notification,
        id: generateId(),
        timestamp: Date.now(),
        isRead: false,
      };
      return { notifications: [notif, ...state.notifications].slice(0, 50) };
    }
    case 'REMOVE_NOTIFICATION': {
      return { notifications: state.notifications.filter((n) => n.id !== action.id) };
    }
    case 'CLEAR_NOTIFICATIONS': {
      return { notifications: [] };
    }
    case 'MARK_NOTIFICATION_READ': {
      return {
        notifications: state.notifications.map((n) =>
          n.id === action.id ? { ...n, isRead: true } : n
        ),
      };
    }

    case 'ADD_DESKTOP_ICON': {
      const icon: DesktopIcon = { ...action.icon, id: generateId() };
      const next = [...state.desktopIcons, icon];
      try { localStorage.setItem('ubuntuos_desktop_icons', JSON.stringify(next)); } catch {}
      return { desktopIcons: next };
    }
    case 'REMOVE_DESKTOP_ICON': {
      const next = state.desktopIcons.filter((i) => i.id !== action.id);
      try { localStorage.setItem('ubuntuos_desktop_icons', JSON.stringify(next)); } catch {}
      return { desktopIcons: next };
    }
    case 'UPDATE_DESKTOP_ICON_POSITION': {
      const next = state.desktopIcons.map((i) =>
        i.id === action.id ? { ...i, position: action.position } : i
      );
      try { localStorage.setItem('ubuntuos_desktop_icons', JSON.stringify(next)); } catch {}
      return { desktopIcons: next };
    }
    case 'SELECT_DESKTOP_ICON': {
      return {
        desktopIcons: state.desktopIcons.map((i) =>
          ({ ...i, isSelected: i.id === action.id })
        ),
      };
    }

    case 'SET_THEME': {
      return { theme: { ...state.theme, ...action.theme } };
    }
    case 'TOGGLE_THEME': {
      const mode = state.theme.mode === 'dark' ? 'light' : 'dark';
      return { theme: { ...state.theme, mode } };
    }

    case 'PIN_DOCK_ITEM': {
      return {
        dockItems: state.dockItems.map((d) =>
          d.appId === action.appId ? { ...d, isPinned: true } : d
        ),
      };
    }
    case 'UNPIN_DOCK_ITEM': {
      return {
        dockItems: state.dockItems.map((d) =>
          d.appId === action.appId ? { ...d, isPinned: false } : d
        ),
      };
    }
    case 'BOUNCE_DOCK_ITEM': {
      return {
        dockItems: state.dockItems.map((d) =>
          d.appId === action.appId ? { ...d, bounce: true } : { ...d, bounce: false }
        ),
      };
    }

    case 'SHOW_CONTEXT_MENU': {
      return {
        contextMenu: {
          visible: true,
          x: action.x,
          y: action.y,
          type: action.menuType as ContextMenuType,
          items: action.items as ContextMenuItem[],
          contextData: action.contextData,
        },
      };
    }
    case 'HIDE_CONTEXT_MENU': {
      return { contextMenu: { ...state.contextMenu, visible: false } };
    }

    case 'START_ALT_TAB': {
      const visibleWins = state.windows.filter((w) => w.state !== 'minimized');
      return {
        isAltTabbing: true,
        altTabIndex: visibleWins.length > 0 ? visibleWins.length - 1 : 0,
      };
    }
    case 'CYCLE_ALT_TAB': {
      const visibleWins = state.windows.filter((w) => w.state !== 'minimized');
      return {
        altTabIndex: visibleWins.length > 0
          ? (state.altTabIndex + 1) % visibleWins.length
          : 0,
      };
    }
    case 'END_ALT_TAB': {
      const visibleWins = state.windows.filter((w) => w.state !== 'minimized');
      const target = visibleWins[state.altTabIndex];
      const windowUpdates: Partial<OSState> = {
        isAltTabbing: false,
        altTabIndex: 0,
      };
      if (target) {
        windowUpdates.activeWindowId = target.id;
        windowUpdates.windows = state.windows.map((w) =>
          w.id === target.id ? { ...w, isFocused: true, zIndex: state.nextZIndex } : { ...w, isFocused: false }
        );
        windowUpdates.nextZIndex = state.nextZIndex + 1;
      }
      return windowUpdates;
    }

    default:
      return {};
  }
}
