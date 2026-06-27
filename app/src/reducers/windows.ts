import type { OSState, Window, WindowState } from '@/types';
import { getAppById } from '@/apps/registry';

const generateId = () => Math.random().toString(36).slice(2) + Date.now().toString(36);
const TOP_PANEL_HEIGHT = 28;

const createWindow = (state: OSState, appId: string, title?: string): Window => {
  const app = getAppById(appId);
  if (!app) throw new Error(`Unknown app: ${appId}`);
  const id = generateId();
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const offset = (state.windows.filter((w) => w.appId === appId && w.state !== 'minimized').length) * 30;
  const x = Math.max(20, Math.min(vw - app.defaultSize.width - 20, 60 + offset));
  const y = Math.max(TOP_PANEL_HEIGHT + 10, Math.min(vh - app.defaultSize.height - 60, 40 + offset));
  return {
    id,
    appId,
    title: title || app.name,
    position: { x, y },
    size: { ...app.defaultSize },
    state: 'normal',
    isFocused: true,
    zIndex: state.nextZIndex,
    icon: app.icon,
    createdAt: Date.now(),
  };
};

export interface WindowActionPatch extends Partial<OSState> {
  dockBounce?: string;
}

export function handleWindowAction(state: OSState, action: any): WindowActionPatch {
  switch (action.type) {
    case 'OPEN_WINDOW': {
      const win = createWindow(state, action.appId, action.title);
      const newWindows = state.windows.map((w) => ({ ...w, isFocused: false }));
      return {
        windows: [...newWindows, win],
        activeWindowId: win.id,
        nextZIndex: state.nextZIndex + 1,
        dockBounce: action.appId,
      };
    }

    case 'CLOSE_WINDOW': {
      const appId = state.windows.find((w) => w.id === action.windowId)?.appId;
      const remaining = state.windows.filter((w) => w.id !== action.windowId);
      const newActiveId = remaining.length > 0
        ? remaining.reduce((a, b) => (a.zIndex > b.zIndex ? a : b)).id
        : null;
      return {
        windows: remaining,
        activeWindowId: newActiveId,
      };
    }

    case 'MINIMIZE_WINDOW': {
      const win = state.windows.find((w) => w.id === action.windowId);
      if (!win) return {};
      const updated = state.windows.map((w) =>
        w.id === action.windowId
          ? { ...w, state: 'minimized' as WindowState, isFocused: false, prevPosition: { ...w.position }, prevSize: { ...w.size } }
          : w
      );
      const newActiveId = updated
        .filter((w) => w.state !== 'minimized')
        .reduce((a, b) => (a && a.zIndex > b.zIndex ? a : b), null as Window | null);
      return { windows: updated, activeWindowId: newActiveId?.id ?? null };
    }

    case 'MAXIMIZE_WINDOW': {
      const vw = window.innerWidth;
      const vh = window.innerHeight;
      return {
        windows: state.windows.map((w) =>
          w.id === action.windowId
            ? {
                ...w,
                state: 'maximized' as WindowState,
                prevPosition: { ...w.position },
                prevSize: { ...w.size },
                position: { x: 0, y: TOP_PANEL_HEIGHT },
                size: { width: vw, height: vh - TOP_PANEL_HEIGHT - 48 },
              }
            : w
        ),
      };
    }

    case 'RESTORE_WINDOW': {
      const win = state.windows.find((w) => w.id === action.windowId);
      if (!win) return {};
      return {
        windows: state.windows.map((w) =>
          w.id === action.windowId
            ? {
                ...w,
                state: 'normal' as WindowState,
                position: win.prevPosition || w.position,
                size: win.prevSize || w.size,
                prevPosition: undefined,
                prevSize: undefined,
              }
            : w
        ),
      };
    }

    case 'FOCUS_WINDOW': {
      const nextZ = state.nextZIndex + 1;
      return {
        windows: state.windows.map((w) =>
          w.id === action.windowId
            ? { ...w, isFocused: true, zIndex: nextZ }
            : { ...w, isFocused: false }
        ),
        activeWindowId: action.windowId,
        nextZIndex: nextZ,
      };
    }

    case 'MOVE_WINDOW': {
      return {
        windows: state.windows.map((w) =>
          w.id === action.windowId ? { ...w, position: action.position } : w
        ),
      };
    }

    case 'RESIZE_WINDOW': {
      return {
        windows: state.windows.map((w) =>
          w.id === action.windowId ? { ...w, size: action.size } : w
        ),
      };
    }

    case 'SET_ACTIVE_WINDOW': {
      return {
        activeWindowId: action.windowId,
        windows: state.windows.map((w) => ({ ...w, isFocused: w.id === action.windowId })),
      };
    }

    case 'CASCADE_WINDOWS': {
      let z = state.nextZIndex;
      const updated = state.windows.map((w, i) => ({
        ...w,
        position: { x: 40 + i * 30, y: TOP_PANEL_HEIGHT + 20 + i * 30 },
        zIndex: z++,
        isFocused: i === state.windows.length - 1,
      }));
      return {
        windows: updated,
        activeWindowId: updated.length > 0 ? updated[updated.length - 1].id : null,
        nextZIndex: z,
      };
    }

    case 'MINIMIZE_ALL': {
      return {
        windows: state.windows.map((w) =>
          w.state !== 'minimized'
            ? { ...w, state: 'minimized' as WindowState, isFocused: false }
            : w
        ),
        activeWindowId: null,
      };
    }

    default:
      return {};
  }
}
