# Pattern: Right-Click Context Menu

## Problem

Context menus must appear at the cursor without overflowing the viewport, close when the user clicks outside or presses Escape, and be reachable by keyboard (Shift+F10 is the standard trigger). The naive approach of positioning at `e.clientX/Y` breaks near viewport edges.

## Preventing Default and Capturing Position

```tsx
function useContextMenu() {
  const [menu, setMenu] = useState<{ x: number; y: number } | null>(null);

  function onContextMenu(e: React.MouseEvent) {
    e.preventDefault();                        // suppress browser's native menu
    e.stopPropagation();
    setMenu({ x: e.clientX, y: e.clientY });
  }

  function close() {
    setMenu(null);
  }

  return { menu, onContextMenu, close };
}
```

WHY `preventDefault` is required: without it, both your custom menu and the browser's native context menu appear. WHY `stopPropagation`: parent containers may also have `onContextMenu` handlers.

## Viewport-Aware Positioning

Compute the menu's position after render, once you know its dimensions. Use a `useEffect` with a `ref` to flip the menu if it would overflow:

```tsx
const MENU_WIDTH = 200;
const MENU_HEIGHT_ESTIMATE = 200;

function positionMenu(x: number, y: number): React.CSSProperties {
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  return {
    position: 'fixed',
    left: x + MENU_WIDTH > vw ? x - MENU_WIDTH : x,
    top:  y + MENU_HEIGHT_ESTIMATE > vh ? y - MENU_HEIGHT_ESTIMATE : y,
    zIndex: 9999,
  };
}
```

For precise flipping, measure the actual rendered menu size:

```tsx
const menuRef = useRef<HTMLElement>(null);

useEffect(() => {
  if (!menu || !menuRef.current) return;
  const { width, height } = menuRef.current.getBoundingClientRect();
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const left = menu.x + width  > vw ? menu.x - width  : menu.x;
  const top  = menu.y + height > vh ? menu.y - height : menu.y;
  menuRef.current.style.left = `${left}px`;
  menuRef.current.style.top  = `${top}px`;
}, [menu]);
```

## Click-Outside and Escape to Close

```tsx
useEffect(() => {
  if (!menu) return;
  function handleClick() { close(); }
  function handleKey(e: KeyboardEvent) {
    if (e.key === 'Escape') close();
  }
  document.addEventListener('click', handleClick);
  document.addEventListener('keydown', handleKey);
  return () => {
    document.removeEventListener('click', handleClick);
    document.removeEventListener('keydown', handleKey);
  };
}, [menu]);
```

WHY attach to `document`: the click could land on any element, including the backdrop or an iframe boundary.

## Keyboard Trigger (Shift+F10)

```tsx
function onKeyDown(e: React.KeyboardEvent) {
  // Shift+F10 is the standard "application key" equivalent
  if (e.shiftKey && e.key === 'F10') {
    e.preventDefault();
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    setMenu({ x: rect.left, y: rect.bottom });
  }
}
```

## Full Component

```tsx
function ContextMenuTrigger({ items, children }: Props) {
  const { menu, onContextMenu, close } = useContextMenu();

  return (
    <div onContextMenu={onContextMenu} onKeyDown={onKeyDown}>
      {children}
      {menu && (
        <ul
          ref={menuRef}
          role="menu"
          style={{ position: 'fixed', left: menu.x, top: menu.y, zIndex: 9999 }}
          className="rounded-md border bg-white py-1 shadow-lg"
        >
          {items.map(item => (
            <li key={item.label} role="menuitem">
              <button
                className="w-full px-4 py-1.5 text-left text-sm hover:bg-gray-100"
                onClick={() => { item.action(); close(); }}
              >
                {item.label}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

## Key Rules

- `e.preventDefault()` in `onContextMenu` is required — without it the browser menu also appears
- Position at clientX/Y, then flip left/up if the menu would overflow the viewport
- Close on any document `click` and on `Escape` keydown
- Support Shift+F10 as the keyboard context menu trigger (standard cross-platform shortcut)
- Use `role="menu"` + `role="menuitem"` for proper ARIA semantics
