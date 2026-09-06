import { listen, type UnlistenFn } from '@tauri-apps/api/event';
import { useEffect, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from '@/components/ui/use-toast';
import { usePlatform } from '@/platform/PlatformContext';

/**
 * The dictate pill webview pastes into the app that was focused when the
 * chord fired. When that paste fails (AX focus unavailable, activation
 * refused, clipboard write error) the pill still shows its green "Done"
 * state — the failure is invisible from the pill itself. The dictate window
 * emits `dictate:paste-failed`; this hook surfaces it as a destructive
 * toast in the main window, the only surface large enough to explain what
 * happened and where the text landed instead.
 */
export function usePasteFailureToast() {
  const platform = usePlatform();
  const { t } = useTranslation();
  // Ref so the long-lived `listen` callback reads the current locale
  // without re-subscribing on every language change.
  const tRef = useRef(t);
  tRef.current = t;

  useEffect(() => {
    if (!platform.metadata.isTauri) return;
    let unlisten: UnlistenFn | null = null;
    listen<{ message?: string }>('dictate:paste-failed', (event) => {
      const message = event.payload?.message || '';
      toast({
        variant: 'destructive',
        title: tRef.current('captures.pasteFailed.title'),
        description: message || tRef.current('captures.pasteFailed.body'),
      });
    })
      .then((fn) => {
        unlisten = fn;
      })
      .catch(() => {});
    return () => {
      if (unlisten) unlisten();
    };
  }, [platform.metadata.isTauri]);
}
