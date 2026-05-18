# Overflow Menu — "More Actions" Menu

## Trigger and Positioning

The menu opens anchored to its trigger button. Position it bottom-right of the trigger by default — this keeps it within the viewport for most table/card rows. Use `@floating-ui/react` or a headless component library rather than hand-rolling position math; viewport edge detection is non-trivial.

```tsx
import { useFloating, autoUpdate, offset, flip, shift } from '@floating-ui/react'

const { refs, floatingStyles } = useFloating({
  whileElementsMounted: autoUpdate,
  middleware: [
    offset(4),            // 4px gap between trigger and menu
    flip(),               // flip above if no room below
    shift({ padding: 8 }) // keep within viewport with 8px margin
  ],
})
```

The trigger is a `...` icon button (`aria-label="More actions"`). Use `aria-haspopup="menu"` and `aria-expanded` on the trigger.

## Menu Structure

```tsx
<div role="menu" aria-label="Row actions">
  <div role="group" aria-label="Edit actions">
    <button role="menuitem" onClick={onEdit}>
      <Pencil className="w-4 h-4" aria-hidden="true" />
      Edit
    </button>
    <button role="menuitem" onClick={onDuplicate}>
      <Copy className="w-4 h-4" aria-hidden="true" />
      Duplicate
    </button>
  </div>
  <hr role="separator" />
  <div role="group" aria-label="Danger actions">
    <button role="menuitem" onClick={onDelete} className="text-destructive">
      <Trash className="w-4 h-4" aria-hidden="true" />
      Delete
    </button>
  </div>
</div>
```

Group related actions with `<hr role="separator">`. Destructive actions (Delete, Archive) go in their own group at the bottom, styled with `text-destructive`.

Icons are `aria-hidden="true"` — the label text is the accessible name.

## Keyboard Navigation

`role="menu"` requires full arrow-key navigation to comply with ARIA. This is non-trivial to implement manually:

- `ArrowDown` / `ArrowUp` move between `menuitem` elements.
- `Home` / `End` jump to first/last.
- `Escape` closes the menu and returns focus to trigger.
- `Enter` / `Space` activates the focused item.
- Tab closes the menu (focus leaves).

Use a library (Radix UI `DropdownMenu`, Headless UI `Menu`) that implements this correctly rather than building it from scratch. The spec has edge cases around nested menus, disabled items, and focus restoration that bite every hand-rolled implementation.

## When to Show: Click vs Hover

**Click** is almost always correct. Hover menus are a usability trap:
- They interfere with pointer movement across the row.
- They don't work on touch.
- They cause accidental opens/closes.

Exception: a tooltip-style info popup can be hover, but not an action menu.

## Item Grouping Logic

Group actions by consequence, not by frequency:
1. Primary actions (Edit, View, Open)
2. Secondary actions (Duplicate, Export, Share)
3. Separator
4. Destructive actions (Archive, Delete)

Items within a group should be ordered most-used first. Don't alphabetize.

## Closing Behavior

Close on: item activation, Escape, click outside, scroll of the scrollable ancestor. Don't close on resize — the `autoUpdate` from floating-ui handles repositioning.

```ts
// Close on outside click
useEffect(() => {
  if (!open) return
  const handler = (e: MouseEvent) => {
    if (!refs.floating.current?.contains(e.target as Node) &&
        !refs.reference.current?.contains(e.target as Node)) {
      setOpen(false)
    }
  }
  document.addEventListener('mousedown', handler)
  return () => document.removeEventListener('mousedown', handler)
}, [open])
```

## Key Rules

- Use `@floating-ui` or a headless library for positioning — don't hand-roll viewport math.
- `aria-haspopup="menu"` and `aria-expanded` on the trigger button.
- Full arrow-key navigation required for `role="menu"` — use Radix/Headless UI.
- Click to open, not hover. Hover menus break on touch and cause accidental activations.
- Destructive items isolated in their own group at bottom, styled with destructive color.
- Close on: item click, Escape, outside click, ancestor scroll.
