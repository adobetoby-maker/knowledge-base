# Pattern: Split Button

A split button joins a primary action with a dropdown of alternatives. The key constraint: the main button and the chevron trigger are **two separate interactive elements** with a visual seam between them—not one button with an embedded icon.

## Why It Matters

Combining primary + secondary actions into one control saves space and reduces cognitive load. But the split must be real: users need to click the label to invoke the action and click the chevron to see alternatives. Fusing them into one `<button>` means every click opens the dropdown, eliminating the quick-action benefit entirely.

## Structure

```tsx
<div className="split-button" role="group" aria-label="Save options">
  {/* Primary action */}
  <button
    type="button"
    onClick={handlePrimaryAction}
    className="split-button__main"
  >
    Save
  </button>

  {/* Divider is visual only — CSS border-right on main button */}

  {/* Dropdown trigger */}
  <button
    type="button"
    className="split-button__chevron"
    aria-haspopup="menu"
    aria-expanded={isOpen}
    aria-label="More save options"
    onClick={() => setIsOpen(o => !o)}
    onKeyDown={handleChevronKeyDown}
  >
    <ChevronDownIcon aria-hidden />
  </button>

  {isOpen && (
    <ul role="menu" className="split-button__menu" ref={menuRef}>
      {options.map((opt, i) => (
        <li key={opt.id} role="none">
          <button
            role="menuitem"
            tabIndex={focusIndex === i ? 0 : -1}
            onClick={() => { opt.action(); setIsOpen(false); }}
          >
            {opt.label}
          </button>
        </li>
      ))}
    </ul>
  )}
</div>
```

## Keyboard Behavior

The keyboard spec has two distinct zones:

**On the main button:**
- `Enter` / `Space` — invoke primary action immediately, no dropdown
- `Tab` — moves focus to chevron button

**On the chevron button:**
- `Enter` / `Space` — open dropdown
- `ArrowDown` — open dropdown and focus first item
- `ArrowUp` — open dropdown and focus last item
- `Escape` — close dropdown, return focus to chevron

**Inside the menu:**
- `ArrowDown` / `ArrowUp` — navigate items (no wrap-around required but preferred)
- `Enter` / `Space` — invoke item, close menu
- `Escape` — close menu, return focus to chevron
- `Tab` — close menu (natural tab exit)

```ts
function handleChevronKeyDown(e: KeyboardEvent<HTMLButtonElement>) {
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    setIsOpen(true);
    setFocusIndex(0);
  }
  if (e.key === 'ArrowUp') {
    e.preventDefault();
    setIsOpen(true);
    setFocusIndex(options.length - 1);
  }
  if (e.key === 'Escape') setIsOpen(false);
}

function handleMenuKeyDown(e: KeyboardEvent, currentIndex: number) {
  if (e.key === 'ArrowDown') { e.preventDefault(); setFocusIndex(i => Math.min(i + 1, options.length - 1)); }
  if (e.key === 'ArrowUp')   { e.preventDefault(); setFocusIndex(i => Math.max(i - 1, 0)); }
  if (e.key === 'Escape')    { setIsOpen(false); chevronRef.current?.focus(); }
}
```

## ARIA Wiring

- `role="group"` on the container with `aria-label` describing the combined control
- `aria-haspopup="menu"` on the chevron—signals to screen readers that activation opens a menu
- `aria-expanded` on the chevron—reflects current open/closed state
- `aria-label="More save options"` on the chevron—the icon alone has no text
- `role="menu"` / `role="menuitem"` on dropdown list/items
- `tabIndex={focusIndex === i ? 0 : -1}` implements roving tabindex inside the menu

## Loading / Disabled States

```tsx
// Disable both targets independently
<button disabled={isSaving} className="split-button__main">
  {isSaving ? <Spinner /> : 'Save'}
</button>
<button disabled={isSaving || isOpen} className="split-button__chevron" ...>
```

Disable the primary during async to prevent double-submit. Disable the chevron only if the entire set of options is unavailable—don't disable it just because the primary is loading.

## Close on Outside Click

```ts
useEffect(() => {
  if (!isOpen) return;
  const handler = (e: MouseEvent) => {
    if (!containerRef.current?.contains(e.target as Node)) setIsOpen(false);
  };
  document.addEventListener('mousedown', handler);
  return () => document.removeEventListener('mousedown', handler);
}, [isOpen]);
```

## Key Rules

- **Two separate `<button>` elements**—never one button with a chevron inside.
- **`aria-haspopup="menu"`** on the chevron, not on the primary button.
- **`Enter` on primary fires action**—it must never open the dropdown.
- **`ArrowDown` on chevron** opens menu and focuses first item without a second keypress.
- **Roving tabindex** inside menu—not sequential tab stops.
- **Close on Escape** and return focus to chevron, not to primary.
- **`role="group"`** on the wrapper keeps the control semantically unified for screen readers.
