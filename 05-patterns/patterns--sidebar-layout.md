# Pattern: Application Layout with Collapsible Sidebar

## Why This Pattern Matters

The sidebar is the skeleton of an app — it's always visible and always in the user's peripheral vision. A poorly implemented sidebar leaks layout on mobile, fights with the main content on small desktops, and loses its collapsed state on every refresh. These are small annoyances that compound into product distrust over time.

## The Core Responsive Pattern

Mobile and desktop use fundamentally different approaches. Don't fight this with a single CSS solution.

**Desktop (lg+):** Sidebar is always mounted. Use `translate-x-0` when expanded, `-translate-x-full` when collapsed. The main content area shifts with a matching `ml-64` / `ml-0` transition. Both animate with `transition-[width,transform]`.

**Mobile (<lg):** Sidebar slides over content — it's an overlay, not a pusher. A backdrop appears behind it. Body scroll locks while open.

```tsx
<>
  {/* Backdrop — mobile only */}
  {mobileOpen && (
    <div
      className="fixed inset-0 bg-black/50 z-20 lg:hidden"
      onClick={() => setMobileOpen(false)}
    />
  )}

  {/* Sidebar */}
  <aside className={cn(
    'fixed top-0 left-0 h-full z-30 w-64 bg-background border-r',
    'transition-transform duration-200',
    'lg:translate-x-0',
    mobileOpen ? 'translate-x-0' : '-translate-x-full',
    desktopCollapsed && 'lg:-translate-x-full',
  )} />

  {/* Main content */}
  <main className={cn(
    'transition-[margin] duration-200',
    'lg:ml-64',
    desktopCollapsed && 'lg:ml-0',
  )}>
    {children}
  </main>
</>
```

## Persisting Collapse State

Use `localStorage` so the user's preference survives page refresh and navigation:

```ts
function useLocalStorage<T>(key: string, initial: T) {
  const [value, setValue] = useState<T>(() => {
    try { return JSON.parse(localStorage.getItem(key) ?? '') ?? initial; }
    catch { return initial; }
  });
  const set = (v: T) => { setValue(v); localStorage.setItem(key, JSON.stringify(v)); };
  return [value, set] as const;
}

const [collapsed, setCollapsed] = useLocalStorage('sidebar:collapsed', false);
```

Never store this in the URL — it's a UI preference, not navigational state.

## Toggle Button Accessibility

The hamburger/toggle button must have `aria-expanded` and `aria-controls` pointing to the sidebar's `id`:

```tsx
<button
  aria-expanded={!collapsed}
  aria-controls="main-sidebar"
  aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
  onClick={() => setCollapsed(c => !c)}
>
  <PanelLeft className="h-5 w-5" />
</button>

<aside id="main-sidebar" aria-label="Main navigation" ...>
```

## Keyboard Shortcut to Toggle

`Ctrl+B` / `Cmd+B` is the convention (VS Code, Notion, Linear). Register it globally:

```ts
useEffect(() => {
  const handler = (e: KeyboardEvent) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'b') {
      e.preventDefault();
      setCollapsed(c => !c);
    }
  };
  document.addEventListener('keydown', handler);
  return () => document.removeEventListener('keydown', handler);
}, []);
```

Show the shortcut in a tooltip on the toggle button.

## Icon-Only Collapsed State

In desktop collapsed mode, keep the sidebar at `w-16` (icon-only) rather than `w-0`. This preserves navigation affordance without eating content width. Show tooltips on hover for each icon. Nav item text fades out with `opacity-0 overflow-hidden w-0` and `transition-all`.

## Key Rules

- Mobile = overlay with backdrop; desktop = pusher (content shifts)
- Persist collapse state in `localStorage`, not URL or server state
- `aria-expanded` and `aria-controls` required on toggle button
- Keyboard shortcut: `Cmd+B` / `Ctrl+B`
- Collapsed desktop = icon-only at `w-16`, not hidden entirely
- Body scroll locks when mobile sidebar is open
- Transitions on `transform` and `margin`, not `width` (avoids reflow)
