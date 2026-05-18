# Pattern: Hamburger Mobile Nav

A hamburger button that opens a full-screen navigation overlay on mobile. Covers focus trap, escape to close, slide-in animation, and body scroll lock.

## Why Each Piece Matters

- **Focus trap**: Without it, keyboard/screen reader users can tab into hidden content behind the menu
- **Escape to close**: The standard keyboard interaction for overlays; users expect it
- **Scroll lock**: Without it, the background page scrolls while the menu is open — creates disorientation on iOS
- **Slide animation**: Signals the layer relationship (menu is above page, not replacing it)

## Focus Trap Implementation

Use `focus-trap-react` or implement manually. The manual approach:

```tsx
function useFocusTrap(containerRef: React.RefObject<HTMLElement>, enabled: boolean) {
  useEffect(() => {
    if (!enabled) return;
    const container = containerRef.current;
    if (!container) return;

    const focusableSelectors = 'a[href], button:not([disabled]), input, textarea, select, [tabindex]:not([tabindex="-1"])';
    const focusableEls = Array.from(container.querySelectorAll<HTMLElement>(focusableSelectors));
    const first = focusableEls[0];
    const last = focusableEls[focusableEls.length - 1];

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key !== 'Tab') return;
      if (e.shiftKey) {
        if (document.activeElement === first) { e.preventDefault(); last.focus(); }
      } else {
        if (document.activeElement === last) { e.preventDefault(); first.focus(); }
      }
    };

    first?.focus(); // move focus into menu on open
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [enabled, containerRef]);
}
```

## Body Scroll Lock

On iOS, `overflow: hidden` on `body` doesn't prevent scroll — the body itself scrolls. Use a fixed position technique:

```tsx
function useScrollLock(enabled: boolean) {
  useEffect(() => {
    if (!enabled) return;

    const scrollY = window.scrollY;
    document.body.style.position = 'fixed';
    document.body.style.top = `-${scrollY}px`;
    document.body.style.width = '100%';

    return () => {
      document.body.style.position = '';
      document.body.style.top = '';
      document.body.style.width = '';
      // Restore scroll position after unlocking
      window.scrollTo(0, scrollY);
    };
  }, [enabled]);
}
```

Storing and restoring `scrollY` is critical — without it, the page jumps to the top when the menu closes.

## Menu Component

```tsx
function MobileMenu({ isOpen, onClose, navItems }: {
  isOpen: boolean;
  onClose: () => void;
  navItems: NavItem[];
}) {
  const menuRef = useRef<HTMLDivElement>(null);
  useFocusTrap(menuRef, isOpen);
  useScrollLock(isOpen);

  // Close on Escape
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [onClose]);

  return (
    <>
      {/* Backdrop */}
      <div
        className={cn('fixed inset-0 bg-black/50 z-40 transition-opacity', isOpen ? 'opacity-100' : 'opacity-0 pointer-events-none')}
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Menu panel */}
      <div
        ref={menuRef}
        role="dialog"
        aria-modal="true"
        aria-label="Navigation menu"
        className={cn(
          'fixed inset-y-0 right-0 z-50 w-full max-w-sm bg-background shadow-xl flex flex-col transition-transform duration-300',
          isOpen ? 'translate-x-0' : 'translate-x-full'
        )}
      >
        {/* Close button */}
        <div className="flex items-center justify-between p-4 border-b">
          <span className="font-semibold">Menu</span>
          <button
            onClick={onClose}
            aria-label="Close menu"
            className="p-2 rounded-md hover:bg-muted"
          >
            <XIcon size={20} />
          </button>
        </div>

        {/* Nav items */}
        <nav className="flex-1 overflow-y-auto p-4 space-y-1">
          {navItems.map(item => (
            <a
              key={item.href}
              href={item.href}
              onClick={onClose} // close menu on navigation
              className="flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium hover:bg-muted"
            >
              {item.icon && <item.icon size={18} />}
              {item.label}
            </a>
          ))}
        </nav>
      </div>
    </>
  );
}
```

## Hamburger Button

```tsx
function HamburgerButton({ isOpen, onClick }: { isOpen: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      aria-expanded={isOpen}
      aria-controls="mobile-menu"
      aria-label={isOpen ? 'Close menu' : 'Open menu'}
      className="p-2 rounded-md lg:hidden"
    >
      {isOpen ? <XIcon size={24} /> : <MenuIcon size={24} />}
    </button>
  );
}
```

`aria-expanded` on the trigger communicates the menu state to screen readers. `aria-controls` links trigger to the dialog by ID.

## Animation Approach

Use `translate-x-full` / `translate-x-0` with `transition-transform`. This is GPU-accelerated and avoids layout shifts. Don't animate `left`, `right`, `width`, or `display` — they trigger layout reflow.

## Key Rules

- Focus trap is mandatory — without it, keyboard users escape into the document behind the menu
- iOS scroll lock requires the `position: fixed` technique — `overflow: hidden` alone doesn't work on iOS Safari
- Always save and restore `scrollY` around the scroll lock — otherwise the page jumps to top on close
- `role="dialog"` + `aria-modal="true"` tells screen readers to restrict browsing to the dialog
- `translate-x-full` animation is GPU-accelerated; never animate layout properties on overlays
- Close the menu on navigation (`onClick={onClose}`) — in SPAs the page doesn't reload automatically
