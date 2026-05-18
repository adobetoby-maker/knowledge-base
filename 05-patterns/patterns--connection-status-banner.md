# Pattern: Connection Status Banner (Offline/Reconnecting)

## Overview
Applications that rely on network connectivity owe users transparency when that connectivity is lost. An offline banner gives users three things: awareness (I'm not imagining it — the app is offline), context (changes may not save), and recovery feedback (it reconnected). The implementation must distinguish between browser-level offline detection and application-level connectivity (WebSocket disconnection), as these are different failure modes with different implications.

## Implementation

### Browser-Level Offline Detection
The `navigator.onLine` property and `online`/`offline` events detect OS-level network availability:

```tsx
function useNetworkStatus() {
  const [online, setOnline] = useState(navigator.onLine);

  useEffect(() => {
    const handleOnline = () => setOnline(true);
    const handleOffline = () => setOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  return online;
}
```

### WebSocket Connection Status
Browser `navigator.onLine` does not detect application-level disconnections (server down, WebSocket dropped). Track separately:

```tsx
function useWebSocketStatus(ws: WebSocket | null) {
  const [wsOnline, setWsOnline] = useState(ws?.readyState === WebSocket.OPEN);

  useEffect(() => {
    if (!ws) return;
    const handleOpen = () => setWsOnline(true);
    const handleClose = () => setWsOnline(false);
    ws.addEventListener('open', handleOpen);
    ws.addEventListener('close', handleClose);
    return () => {
      ws.removeEventListener('open', handleOpen);
      ws.removeEventListener('close', handleClose);
    };
  }, [ws]);

  return wsOnline;
}
```

### Combined Status Banner
```tsx
type ConnectionState = 'online' | 'offline' | 'reconnecting' | 'ws-disconnected';

function ConnectionBanner({ websocket }: { websocket?: WebSocket }) {
  const browserOnline = useNetworkStatus();
  const wsOnline = useWebSocketStatus(websocket ?? null);

  const [state, setState] = useState<ConnectionState>('online');
  const [dismissTimer, setDismissTimer] = useState<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (!browserOnline) {
      setState('offline');
      if (dismissTimer) clearTimeout(dismissTimer);
    } else if (websocket && !wsOnline) {
      setState('ws-disconnected');
    } else {
      // Just came back online
      if (state !== 'online') {
        setState('reconnecting');
        const timer = setTimeout(() => setState('online'), 3000);
        setDismissTimer(timer);
      }
    }

    return () => {
      if (dismissTimer) clearTimeout(dismissTimer);
    };
  }, [browserOnline, wsOnline]);

  if (state === 'online') return null;

  const MESSAGES: Record<ConnectionState, { text: string; bg: string; color: string }> = {
    offline: {
      text: 'You are offline. Changes will sync when reconnected.',
      bg: '#fef2f2',
      color: '#991b1b',
    },
    reconnecting: {
      text: 'Reconnected. Syncing your changes...',
      bg: '#f0fdf4',
      color: '#166534',
    },
    'ws-disconnected': {
      text: 'Connection to server lost. Attempting to reconnect...',
      bg: '#fffbeb',
      color: '#92400e',
    },
    online: { text: '', bg: '', color: '' },
  };

  const { text, bg, color } = MESSAGES[state];

  return (
    <div
      role="status"
      aria-live="polite"
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        zIndex: 9999,
        padding: '8px 16px',
        textAlign: 'center',
        fontSize: 14,
        fontWeight: 500,
        background: bg,
        color,
        transition: 'transform 300ms ease',
      }}
    >
      {text}
    </div>
  );
}
```

### Auto-Dismiss After Reconnection
The reconnecting banner auto-dismisses after 3 seconds. The offline banner does not — it stays visible as long as the connection is down.

### Mutation Queue for Offline
Paired with the banner, queue mutations while offline:
```ts
function useMutationQueue() {
  const queue = useRef<Array<() => Promise<void>>>([]);
  const online = useNetworkStatus();

  const enqueue = (mutation: () => Promise<void>) => {
    if (online) {
      mutation();
    } else {
      queue.current.push(mutation);
    }
  };

  // Flush queue when back online
  useEffect(() => {
    if (online && queue.current.length > 0) {
      const pending = [...queue.current];
      queue.current = [];
      pending.forEach(m => m().catch(console.error));
    }
  }, [online]);

  return { enqueue, queueLength: queue.current.length };
}
```

## Key Rules
- `navigator.onLine` returns `true` even when the device has a network interface but no actual internet — it is not a reliable connectivity check. Use it for "definitely offline" detection only.
- Browser `offline`/`online` events and WebSocket connection state are separate concerns — show different messages.
- The "reconnected" banner must auto-dismiss after 3 seconds — a persistent success state is visual clutter.
- The offline banner must not auto-dismiss — the user needs to know they're still offline.
- Use `aria-live="polite"` — screen readers announce the change without interrupting current speech.
- `position: fixed; top: 0` ensures the banner appears above all content including modals; use `zIndex: 9999`.
- Never disable form submission when offline — queue the mutation and submit optimistically.
