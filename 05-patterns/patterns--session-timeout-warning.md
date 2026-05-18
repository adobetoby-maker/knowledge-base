# Pattern: Session Timeout Warning

## Overview
Abrupt session expiry is a destructive user experience — it can cause loss of unsaved form data, disrupt long workflows, and damage trust. The warning pattern gives users a grace period to extend their session before expiry occurs. The implementation must accurately track remaining session time, reset the timer on genuine user activity (not just mouse movement over the warning itself), and avoid false positives from automated events.

## Implementation

### Architecture
The session has a known expiry time (from the JWT `exp` claim or a cookie value). A `useSessionTimeout` hook tracks the remaining time and fires callbacks at the warning threshold and at expiry.

### Hook
```tsx
interface UseSessionTimeoutOptions {
  expiresAt: number;           // Unix timestamp (ms)
  warningThreshold: number;    // ms before expiry to show warning (default: 5 * 60 * 1000)
  onWarning: () => void;
  onExpired: () => void;
  onExtend: () => Promise<void>; // refresh the session token
}

function useSessionTimeout({
  expiresAt,
  warningThreshold = 5 * 60 * 1000,
  onWarning,
  onExpired,
  onExtend,
}: UseSessionTimeoutOptions) {
  const [remaining, setRemaining] = useState<number>(expiresAt - Date.now());
  const [warningShown, setWarningShown] = useState(false);
  const activityRef = useRef<number>(Date.now());

  // Detect genuine user activity — reset session timeout
  useEffect(() => {
    const recordActivity = () => { activityRef.current = Date.now(); };
    const EVENTS = ['mousemove', 'keydown', 'pointerdown', 'scroll', 'touchstart'];
    EVENTS.forEach(e => window.addEventListener(e, recordActivity, { passive: true }));
    return () => EVENTS.forEach(e => window.removeEventListener(e, recordActivity));
  }, []);

  // Countdown tick — runs every 10 seconds (not every second; reduces re-renders)
  useEffect(() => {
    const id = setInterval(() => {
      const now = Date.now();
      const r = expiresAt - now;
      setRemaining(r);

      if (r <= 0) {
        clearInterval(id);
        onExpired();
        return;
      }

      if (r <= warningThreshold && !warningShown) {
        setWarningShown(true);
        onWarning();
      }
    }, 10_000);

    return () => clearInterval(id);
  }, [expiresAt, warningThreshold, warningShown, onWarning, onExpired]);

  const extend = async () => {
    await onExtend();
    setWarningShown(false);
  };

  return { remaining, extend };
}
```

### Warning Modal
```tsx
function SessionWarningModal({
  remaining,
  onStayLoggedIn,
  onLogOut,
}: {
  remaining: number;
  onStayLoggedIn: () => void;
  onLogOut: () => void;
}) {
  const minutes = Math.floor(remaining / 60_000);
  const seconds = Math.floor((remaining % 60_000) / 1000);
  const formatted = `${minutes}:${String(seconds).padStart(2, '0')}`;

  return (
    <dialog open aria-labelledby="session-warning-title" aria-modal="true">
      <h2 id="session-warning-title">Your session is about to expire</h2>
      <p>
        You will be logged out in <strong aria-live="off">{formatted}</strong>.
        Any unsaved changes will be lost.
      </p>
      <div>
        <button onClick={onStayLoggedIn} autoFocus>
          Stay logged in
        </button>
        <button onClick={onLogOut}>
          Log out
        </button>
      </div>
    </dialog>
  );
}
```

### Extend Session Server Action
```ts
async function extendSession() {
  // Re-issue the JWT / refresh cookie
  const newToken = await refreshAuthToken(currentUserId);
  setAuthCookie(newToken);
  return newToken.expiresAt;
}
```

### Integration
```tsx
function AppLayout({ children, session }) {
  const [showWarning, setShowWarning] = useState(false);
  const [expiresAt, setExpiresAt] = useState(session.expiresAt);

  const { remaining, extend } = useSessionTimeout({
    expiresAt,
    warningThreshold: 5 * 60 * 1000,
    onWarning: () => setShowWarning(true),
    onExpired: () => { router.push('/login?reason=expired'); },
    onExtend: async () => {
      const newExpiry = await extendSession();
      setExpiresAt(newExpiry);
      setShowWarning(false);
    },
  });

  return (
    <>
      {children}
      {showWarning && (
        <SessionWarningModal
          remaining={remaining}
          onStayLoggedIn={extend}
          onLogOut={() => signOut()}
        />
      )}
    </>
  );
}
```

## Key Rules
- Show the warning 5 minutes before expiry — earlier feels like noise, later gives no time to save work.
- The countdown in the modal should update every second (local `setInterval` in the modal), but the underlying session check can tick less frequently to reduce re-renders.
- Reset the warning timer on user activity outside the modal — if the user has been typing, they're active and don't need interruption.
- Do not count mouse movement over the modal itself as "user activity" that resets the timer — it would prevent the timer from ever showing.
- The "Stay logged in" call must hit the server — a client-side timestamp change with no token refresh does nothing.
- `autoFocus` on the "Stay logged in" button — keyboard users need immediate access without tabbing through the rest of the page.
- On actual expiry (timer hits zero), force-redirect to login; don't silently invalidate API calls and leave a broken page.
