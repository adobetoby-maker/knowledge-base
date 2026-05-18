# Pattern: Toast Notification with Undo Action

A toast that includes an action button (typically "Undo") alongside its message. A 5-second dismiss timer runs during display, pauses when the user hovers, and the undo callback reverses the original action. Multiple toasts queue without overlap.

## Why It Matters

Destructive actions—delete, archive, move—benefit from a fast undo path. A confirmation dialog breaks flow; an undo toast confirms the action happened while giving a 5-second window to reverse it. This pattern is why Gmail's "Conversation archived" toast feels safe to click through quickly.

## `sonner` Library

Use `sonner` rather than rolling a custom toast system. It handles queuing, animations, hover-pause, and accessibility out of the box:

```tsx
// Root layout
import { Toaster } from 'sonner';
export default function Layout({ children }) {
  return (
    <>
      {children}
      <Toaster
        position="bottom-right"
        duration={5000}
        visibleToasts={3}
        richColors
      />
    </>
  );
}
```

```ts
// Usage — toast with undo
import { toast } from 'sonner';

function handleDelete(item: Item) {
  // 1. Optimistically remove the item
  removeItem(item.id);

  // 2. Show toast with undo
  toast(`"${item.name}" deleted`, {
    action: {
      label: 'Undo',
      onClick: () => {
        restoreItem(item);
        toast.success('Deletion undone');
      },
    },
    duration: 5000,
    onDismiss: () => {
      // 3. Actually delete server-side after toast dismisses without undo
      deleteItemFromServer(item.id);
    },
    onAutoClose: () => {
      deleteItemFromServer(item.id);
    },
  });
}
```

The destructive operation is deferred until the toast closes without undo. The UI updates optimistically so the action feels instant.

## Custom Implementation (without sonner)

If a custom implementation is required:

```tsx
interface Toast {
  id: string;
  message: string;
  action?: { label: string; onClick: () => void };
  duration: number;
}

function useToastQueue() {
  const [toasts, setToasts] = useState<Toast[]>([]);

  function add(toast: Omit<Toast, 'id'>) {
    const id = crypto.randomUUID();
    setToasts(prev => [...prev, { ...toast, id }]);
    return id;
  }

  function remove(id: string) {
    setToasts(prev => prev.filter(t => t.id !== id));
  }

  return { toasts, add, remove };
}

function ToastItem({ toast, onRemove }: { toast: Toast; onRemove: () => void }) {
  const timerRef = useRef<ReturnType<typeof setTimeout>>();
  const [paused, setPaused] = useState(false);
  const remainingRef = useRef(toast.duration);
  const startRef = useRef(Date.now());

  function startTimer() {
    timerRef.current = setTimeout(onRemove, remainingRef.current);
    startRef.current = Date.now();
  }

  function pauseTimer() {
    clearTimeout(timerRef.current);
    remainingRef.current -= Date.now() - startRef.current;
  }

  useEffect(() => {
    startTimer();
    return () => clearTimeout(timerRef.current);
  }, []);

  return (
    <div
      role="status"
      aria-live="polite"
      className="toast"
      onMouseEnter={() => { setPaused(true); pauseTimer(); }}
      onMouseLeave={() => { setPaused(false); startTimer(); }}
    >
      <span>{toast.message}</span>
      {toast.action && (
        <button
          type="button"
          onClick={() => { toast.action!.onClick(); onRemove(); }}
          className="toast-action"
        >
          {toast.action.label}
        </button>
      )}
      <button type="button" onClick={onRemove} aria-label="Dismiss" className="toast-close">×</button>
      {/* Progress bar */}
      <div
        className="toast-progress"
        style={{
          animationDuration: `${toast.duration}ms`,
          animationPlayState: paused ? 'paused' : 'running',
        }}
      />
    </div>
  );
}
```

## Timer Reset on Hover

The hover pause is critical for accessibility—users with motor impairments or slow reading speeds must be able to hover to read and act. The timer resumes from where it paused (not reset to full duration). This means a user who hovers at 3 seconds has 2 seconds remaining after they move away.

## Progress Bar Animation

```css
.toast-progress {
  height: 3px;
  background: var(--accent);
  width: 100%;
  transform-origin: left;
  animation: shrink linear forwards;
}

@keyframes shrink {
  from { transform: scaleX(1); }
  to   { transform: scaleX(0); }
}
```

## Accessible Role

- **`role="status"` + `aria-live="polite"`** for informational toasts (archive, save, copy).
- **`role="alert"` + `aria-live="assertive"`** for error toasts—interrupts screen reader immediately.

Don't use `role="alert"` for undo toasts—they're informational. Reserve `assertive` for errors.

## Toast Queue Limit

```tsx
const MAX_VISIBLE = 3;

// In the Toaster component, only render the last N toasts
const visibleToasts = toasts.slice(-MAX_VISIBLE);
```

When a fourth toast arrives, the oldest silently disappears. Never stack more than 3—they become illegible and obscure content.

## Key Rules

- **Defer the destructive operation** until the toast auto-closes without undo being clicked.
- **Optimistic UI update** first—don't wait to hear back from server before removing the item visually.
- **Hover pauses timer** from current position, not a reset—users get exactly their remaining time.
- **`role="status"` for info**, `role="alert"` for errors—don't interrupt with every toast.
- **Max 3 visible toasts**—oldest dismissed automatically when queue exceeds limit.
- **Use `sonner`** in production—manual timer management has edge cases that `sonner` handles.
- **Undo click removes the toast** immediately—don't make users wait for auto-dismiss after undo.
