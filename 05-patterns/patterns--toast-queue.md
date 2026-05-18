# Pattern: Toast Notification Queue

## Overview
Toasts must be managed as a queue, not individual state values. Without a queue, multiple rapid notifications overwrite each other, auto-dismiss timers conflict, and screen reader announcements are swallowed. The queue maintains ordering, enforces a maximum visible count, and treats accessibility as a first-class concern rather than an afterthought.

## Implementation

### State Model
```ts
interface Toast {
  id: string;
  message: string;
  variant: 'info' | 'success' | 'error' | 'warning';
  duration?: number;       // ms, default 4000; null = never auto-dismiss
  action?: { label: string; onClick: () => void };
}
```

### Queue Context
```tsx
const ToastContext = createContext<{
  add: (toast: Omit<Toast, 'id'>) => void;
  remove: (id: string) => void;
}>(null!);

const MAX_VISIBLE = 3;

function ToastProvider({ children }: { children: React.ReactNode }) {
  const [queue, setQueue] = useState<Toast[]>([]);

  const add = useCallback((toast: Omit<Toast, 'id'>) => {
    const id = crypto.randomUUID();
    setQueue(prev => {
      const next = [...prev, { ...toast, id }];
      // Keep only last MAX_VISIBLE; dismiss oldest when 4th arrives
      return next.length > MAX_VISIBLE ? next.slice(next.length - MAX_VISIBLE) : next;
    });
  }, []);

  const remove = useCallback((id: string) => {
    setQueue(prev => prev.filter(t => t.id !== id));
  }, []);

  return (
    <ToastContext.Provider value={{ add, remove }}>
      {children}
      <ToastContainer queue={queue} remove={remove} />
    </ToastContext.Provider>
  );
}
```

### Individual Toast with Pause-on-Hover
```tsx
function ToastItem({ toast, remove }: { toast: Toast; remove: (id: string) => void }) {
  const [paused, setPaused] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout>>();

  useEffect(() => {
    if (toast.duration === null || paused) return;
    const duration = toast.duration ?? 4000;
    timerRef.current = setTimeout(() => remove(toast.id), duration);
    return () => clearTimeout(timerRef.current);
  }, [toast.id, toast.duration, paused, remove]);

  // Swipe to dismiss on mobile
  const handlers = useSwipe({
    onSwipedLeft: () => remove(toast.id),
    onSwipedRight: () => remove(toast.id),
  });

  return (
    <div
      role="status"
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocus={() => setPaused(true)}
      onBlur={() => setPaused(false)}
      {...handlers}
    >
      <span>{toast.message}</span>
      {toast.action && (
        <button onClick={toast.action.onClick}>{toast.action.label}</button>
      )}
      <button onClick={() => remove(toast.id)} aria-label="Dismiss">✕</button>
    </div>
  );
}
```

### Container Positioning
```tsx
function ToastContainer({ queue, remove }) {
  // Stack from bottom: newest on top = reverse render order
  // Visually: bottom-right, items stacked upward
  return (
    <div
      aria-live="polite"
      aria-atomic="false"
      style={{
        position: 'fixed',
        bottom: 16,
        right: 16,
        zIndex: 9999,
        display: 'flex',
        flexDirection: 'column-reverse',
        gap: 8,
      }}
    >
      {queue.map(t => <ToastItem key={t.id} toast={t} remove={remove} />)}
    </div>
  );
}
```

### Screen Reader Behavior
- `aria-live="polite"`: announced after current speech completes. Use `"assertive"` for errors only.
- `aria-atomic="false"`: each new toast is announced individually, not the whole region.
- The live region must exist in DOM before content is inserted — render the container always, add toasts into it.

### Position Configuration
Expose position as a provider prop: `'top-right' | 'top-center' | 'bottom-right' | 'bottom-center'`. Bottom positions stack upward (`flex-direction: column-reverse`); top positions stack downward (`flex-direction: column`).

## Key Rules
- Never show more than 3 toasts simultaneously — dismiss the oldest when the 4th is added.
- Pause auto-dismiss on hover AND focus (keyboard users navigate into the toast region).
- `aria-live` region must be rendered in the initial DOM — dynamically mounting it and inserting content in the same tick often fails screen readers.
- Use `crypto.randomUUID()` for IDs, not Date.now() — millisecond collisions cause React key conflicts during rapid-fire toasts.
- Errors should use `duration: null` by default and require manual dismissal.
- Swipe-to-dismiss on mobile requires `touch-action: none` on the toast element to prevent scroll interference.
- Never auto-dismiss an error toast — the user may need time to read the message and decide what to do.
