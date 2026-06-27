import { Suspense } from 'react';
import NotImplemented from '@/components/NotImplemented';
import { APP_COMPONENTS } from './appComponents';

interface AppRouterProps {
  appId: string;
  windowId: string;
}

export default function AppRouter({ appId }: AppRouterProps) {
  const Component = APP_COMPONENTS[appId];

  if (!Component) {
    return <NotImplemented appId={appId} />;
  }

  return (
    <Suspense fallback={<AppLoading />}>
      <Component />
    </Suspense>
  );
}

function AppLoading() {
  return (
    <div className="flex items-center justify-center h-full" style={{ background: 'var(--bg-window)' }}>
      <div className="flex flex-col items-center gap-3">
        <div className="w-8 h-8 rounded-full border-2 border-t-transparent animate-spin" style={{ borderColor: 'var(--accent-primary)', borderTopColor: 'transparent' }} />
        <span className="text-xs text-[var(--text-secondary)]">Loading app...</span>
      </div>
    </div>
  );
}
