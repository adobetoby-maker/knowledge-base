# Pattern: Split Pane / Resizable Layout

## Overview
Implementing split panes with absolute pixel math breaks when the container resizes because the stored pixel value no longer represents the intended ratio. Storing ratio (0–1) and computing pixels from the current container width makes the layout stable across window resizes. The collapsed state needs a separate toggle button — dragging to zero is an accidental gesture that traps users.

## Core Resize Logic

```ts
// Store ratio, not pixels — ratio survives container resize
// ratio = panelAWidth / totalContainerWidth

function useSplitPane(containerId: string, storageKey?: string) {
  const [ratio, setRatio] = usePersistedRatio(storageKey, 0.5); // Default 50/50
  const containerRef = useRef<HTMLDivElement>(null);
  const MIN_RATIO = 0.15; // 15% minimum — prevents unusable collapsed state
  const MAX_RATIO = 0.85;

  function startDrag(e: React.PointerEvent) {
    e.preventDefault();
    const container = containerRef.current;
    if (!container) return;

    const { left, width } = container.getBoundingClientRect();
    const handle = e.currentTarget as HTMLElement;
    handle.setPointerCapture(e.pointerId); // Prevent losing events on fast drag

    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';

    function onMove(moveE: PointerEvent) {
      const newRatio = (moveE.clientX - left) / width;
      // Clamp to min/max — don't allow dragging to zero
      setRatio(Math.min(MAX_RATIO, Math.max(MIN_RATIO, newRatio)));
    }

    function onUp() {
      handle.removeEventListener('pointermove', onMove);
      handle.removeEventListener('pointerup', onUp);
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
    }

    handle.addEventListener('pointermove', onMove);
    handle.addEventListener('pointerup', onUp);
  }

  return { ratio, setRatio, containerRef, startDrag };
}

// Persist ratio — but throttle writes to once per drag end
function usePersistedRatio(key: string | undefined, initial: number) {
  const [ratio, setRatio] = useState<number>(() => {
    if (!key) return initial;
    try { return parseFloat(localStorage.getItem(key) ?? '') || initial; } catch { return initial; }
  });

  const persist = useCallback(debounce((r: number) => {
    if (key) localStorage.setItem(key, String(r));
  }, 200), [key]);

  function update(r: number) { setRatio(r); persist(r); }

  return [ratio, update] as const;
}
```

## Collapse Toggle

```tsx
// Separate collapse from drag — a button click is intentional, drag to zero is not
// Remember the pre-collapse ratio so you can restore it

function useSplitPaneCollapse(ratio: number, setRatio: (r: number) => void) {
  const [collapsed, setCollapsed] = useState(false);
  const preCollapseRatio = useRef(ratio);

  function toggle() {
    if (collapsed) {
      setRatio(preCollapseRatio.current);
      setCollapsed(false);
    } else {
      preCollapseRatio.current = ratio;
      setRatio(0); // Visually collapse — pane has display:none or width:0
      setCollapsed(true);
    }
  }

  return { collapsed, toggle };
}
```

## Component

```tsx
function SplitPane({ left, right, storageKey, direction = 'horizontal' }: SplitPaneProps) {
  const { ratio, containerRef, startDrag } = useSplitPane(storageKey);
  const { collapsed, toggle } = useSplitPaneCollapse(ratio, setRatio);

  const leftSize = `${ratio * 100}%`;
  const rightSize = `${(1 - ratio) * 100}%`;

  return (
    <div
      ref={containerRef}
      className={`split-pane split-pane--${direction}`}
      style={{ display: 'flex' }}
    >
      <div
        className="split-pane__panel split-pane__panel--a"
        style={{ width: collapsed ? 0 : leftSize, overflow: 'hidden' }}
        hidden={collapsed} // Screen readers skip hidden pane
      >
        {left}
      </div>

      <div
        className="split-pane__divider"
        onPointerDown={startDrag}
        role="separator"
        aria-orientation={direction === 'horizontal' ? 'vertical' : 'horizontal'}
        aria-valuenow={Math.round(ratio * 100)}
        aria-valuemin={15}
        aria-valuemax={85}
        tabIndex={0}
        onKeyDown={handleKeyboard} // Arrow keys for accessibility
      >
        {/* Collapse toggle button on the divider itself */}
        <button
          className="split-pane__collapse-btn"
          onClick={toggle}
          aria-label={collapsed ? 'Expand panel' : 'Collapse panel'}
        >
          {collapsed ? '›' : '‹'}
        </button>
      </div>

      <div
        className="split-pane__panel split-pane__panel--b"
        style={{ width: rightSize, flex: collapsed ? 1 : undefined }}
      >
        {right}
      </div>
    </div>
  );
}
```

## Keyboard Accessibility

```ts
function handleKeyboard(e: React.KeyboardEvent) {
  const STEP = 0.02; // 2% per arrow key press
  if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
    setRatio(r => Math.max(MIN_RATIO, r - STEP));
    e.preventDefault();
  }
  if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
    setRatio(r => Math.min(MAX_RATIO, r + STEP));
    e.preventDefault();
  }
}
```

## Key Rules
- Store ratio (0–1), not pixels — pixels break when the container is resized
- Use `setPointerCapture` on the drag handle — keeps events flowing on fast drags
- Enforce min/max ratio (15%–85%) during drag — never allow dragging to zero
- Provide a dedicated collapse toggle button that restores the pre-collapse ratio
- Persist ratio to localStorage on drag end (debounced), not on every pointermove
- Add `role="separator"` with `aria-valuenow/min/max` for accessibility
- Support arrow-key resize for keyboard users — 2% per press is a reasonable step
