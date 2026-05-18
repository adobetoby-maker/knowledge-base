# Pattern: Application Menu Bar

A Mac/Windows-style top menu bar with File, Edit, View-style dropdown menus. Covers keyboard navigation, hover intent delay, nested submenus, and focus management.

## Why This Differs from a Nav Menu

A navigation menu links to pages. A menu bar triggers actions. The keyboard interaction model follows the ARIA APG "Menu and Menubar" pattern: arrow keys move between items, space/enter activates, escape closes. This is distinct from the navigation menu pattern where tab key moves between items.

## ARIA Roles

Use `role="menubar"` on the container, `role="menu"` on each dropdown, and `role="menuitem"` on each item.

```tsx
<nav role="menubar" aria-label="Application menu" className="flex">
  {menus.map(menu => (
    <MenuBarItem key={menu.id} menu={menu} />
  ))}
</nav>
```

## Hover Intent Delay

Opening menus on hover without delay causes accidental openings as the mouse passes through. Add a 150–200ms delay on open; close immediately.

```tsx
function useHoverIntent(delay = 150) {
  const [isHovered, setIsHovered] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout>>();

  const onMouseEnter = () => {
    timer.current = setTimeout(() => setIsHovered(true), delay);
  };
  const onMouseLeave = () => {
    clearTimeout(timer.current);
    setIsHovered(false); // close immediately
  };

  return { isHovered, onMouseEnter, onMouseLeave };
}
```

Once any menu is open, subsequent hovers should open instantly (no delay while a menu is already active):

```tsx
// In the menu bar parent:
const [activeMenu, setActiveMenu] = useState<string | null>(null);
// When a menu is already open, skip the delay on hover
const openDelay = activeMenu ? 0 : 150;
```

## Keyboard Navigation

```tsx
function MenuBarItem({ menu, isOpen, onOpen, onClose }: MenuBarItemProps) {
  const triggerRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLUListElement>(null);

  const handleTriggerKeyDown = (e: React.KeyboardEvent) => {
    switch (e.key) {
      case 'Enter':
      case ' ':
      case 'ArrowDown':
        e.preventDefault();
        onOpen();
        // Focus first menu item after opening
        requestAnimationFrame(() => {
          menuRef.current?.querySelector<HTMLElement>('[role="menuitem"]')?.focus();
        });
        break;
      case 'ArrowLeft':
        e.preventDefault();
        focusPrevMenuBarItem();
        break;
      case 'ArrowRight':
        e.preventDefault();
        focusNextMenuBarItem();
        break;
    }
  };

  const handleMenuKeyDown = (e: React.KeyboardEvent) => {
    const items = Array.from(menuRef.current?.querySelectorAll<HTMLElement>('[role="menuitem"]:not([aria-disabled])') ?? []);
    const currentIndex = items.indexOf(document.activeElement as HTMLElement);

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        items[(currentIndex + 1) % items.length]?.focus();
        break;
      case 'ArrowUp':
        e.preventDefault();
        items[(currentIndex - 1 + items.length) % items.length]?.focus();
        break;
      case 'Escape':
        e.preventDefault();
        onClose();
        triggerRef.current?.focus(); // return focus to trigger
        break;
      case 'Tab':
        onClose(); // close menu but allow tab to continue naturally
        break;
    }
  };
```

`requestAnimationFrame` before focusing the first item gives the menu time to render before focus is attempted.

## Nested Submenus

Submenus open on hover or ArrowRight key press:

```tsx
function MenuItem({ item }: { item: MenuItemDef }) {
  const [subOpen, setSubOpen] = useState(false);

  if (item.submenu) {
    return (
      <li role="none">
        <button
          role="menuitem"
          aria-haspopup="menu"
          aria-expanded={subOpen}
          onMouseEnter={() => setSubOpen(true)}
          onMouseLeave={() => setSubOpen(false)}
          onKeyDown={e => {
            if (e.key === 'ArrowRight') { e.preventDefault(); setSubOpen(true); }
          }}
          className="flex items-center justify-between w-full px-3 py-1.5 text-sm hover:bg-accent"
        >
          {item.label}
          <ChevronRightIcon size={14} />
        </button>
        {subOpen && (
          <ul
            role="menu"
            className="absolute left-full top-0 w-48 bg-popover border rounded-md shadow-md"
          >
            {item.submenu.map(sub => <MenuItem key={sub.id} item={sub} />)}
          </ul>
        )}
      </li>
    );
  }

  return (
    <li role="none">
      <button
        role="menuitem"
        disabled={item.disabled}
        aria-disabled={item.disabled}
        aria-keyshortcuts={item.shortcut} // e.g., "Meta+S"
        onClick={() => { item.action?.(); onClose(); }}
        className="flex items-center justify-between w-full px-3 py-1.5 text-sm hover:bg-accent disabled:opacity-40"
      >
        <span>{item.label}</span>
        {item.shortcut && <kbd className="text-xs text-muted-foreground">{item.shortcut}</kbd>}
      </button>
    </li>
  );
}
```

## Focus Management on Close

When a menu closes, focus must return to the trigger that opened it. Without this, keyboard users lose their place in the page.

```tsx
const handleClose = () => {
  setActiveMenu(null);
  // Return focus to the trigger
  document.querySelector<HTMLElement>(`[data-menu-id="${activeMenu}"]`)?.focus();
};
```

## Key Rules

- Use `role="menubar"`, `role="menu"`, `role="menuitem"` — not nav/ul/li roles, which have different keyboard contracts
- ArrowDown opens the menu and moves focus into it; Escape closes and returns focus to the trigger
- Add hover-open delay (150ms) but close immediately; skip delay when another menu is already open
- `requestAnimationFrame` before focusing the first item — the DOM needs one frame to render
- Nested submenus open on ArrowRight keypress, not just hover
- Display keyboard shortcuts in the menu items (`aria-keyshortcuts` + visual `<kbd>`) — this is where users discover them
