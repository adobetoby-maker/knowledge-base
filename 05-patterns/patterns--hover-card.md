# Pattern: Hover Card (Popover on Hover)

A card that appears when the user hovers an anchor element, showing richer context without a click. The failure modes are: flashing on accidental mouse-through, staying open too long after cursor leaves, and breaking completely on touch devices.

## Why It Matters

Click-to-open popovers interrupt flow. Hover cards surface context inline—user profile on an avatar, stock info on a ticker, definition on a term—without navigation. The delay is the critical design variable: too short causes flash-on-mouseover, too long feels sluggish.

## Delay Strategy

Use 150ms open delay and 100ms close delay. The asymmetry is intentional:
- **Open delay** prevents flashing when the mouse passes through the anchor
- **Close delay** creates a grace period to move from anchor to card without it vanishing

```ts
function useHoverDelay(openDelay = 150, closeDelay = 100) {
  const [visible, setVisible] = useState(false);
  const openTimer = useRef<ReturnType<typeof setTimeout>>();
  const closeTimer = useRef<ReturnType<typeof setTimeout>>();

  function handleEnter() {
    clearTimeout(closeTimer.current);
    openTimer.current = setTimeout(() => setVisible(true), openDelay);
  }

  function handleLeave() {
    clearTimeout(openTimer.current);
    closeTimer.current = setTimeout(() => setVisible(false), closeDelay);
  }

  // Cancel close when cursor moves into the card itself
  function handleCardEnter() { clearTimeout(closeTimer.current); }
  function handleCardLeave() { handleLeave(); }

  return { visible, handleEnter, handleLeave, handleCardEnter, handleCardLeave };
}
```

The card must also call `handleCardEnter/Leave` so the user can move from the anchor into the card without it closing.

## Positioning with floating-ui

```tsx
import { useFloating, offset, flip, shift, useHover, useFocus,
         useInteractions, FloatingPortal } from '@floating-ui/react';

function HoverCard({ anchor, children, content }: HoverCardProps) {
  const [open, setOpen] = useState(false);

  const { refs, floatingStyles, context } = useFloating({
    open,
    onOpenChange: setOpen,
    middleware: [offset(8), flip(), shift({ padding: 8 })],
    placement: 'top',
  });

  // floating-ui handles the delay logic via useHover
  const hover = useHover(context, { delay: { open: 150, close: 100 }, move: false });
  const focus = useFocus(context); // keyboard accessibility
  const { getReferenceProps, getFloatingProps } = useInteractions([hover, focus]);

  return (
    <>
      <span ref={refs.setReference} {...getReferenceProps()} className="hover-anchor">
        {anchor}
      </span>
      <FloatingPortal>
        {open && (
          <div
            ref={refs.setFloating}
            style={floatingStyles}
            {...getFloatingProps()}
            role="tooltip"
            className="hover-card"
          >
            {content}
          </div>
        )}
      </FloatingPortal>
    </>
  );
}
```

Using `floating-ui`'s `useHover` interaction hook is preferable to manual timers because it handles edge cases: cursor entering from the floating element, focus/blur events, and pointer type detection.

## `role="tooltip"` vs `role="dialog"`

- **`role="tooltip"`**: supplementary information, non-interactive. Screen readers read it automatically when the trigger is focused. Use for definitions, previews, metadata. The tooltip must not contain interactive elements (links, buttons).
- **`role="dialog"`**: the card contains interactive content (follow button, links). Requires explicit focus management—move focus into the card on open, return it on close. Triggered by click, not hover.

```tsx
// Tooltip: non-interactive preview
<div role="tooltip" id={tooltipId}>
  <p>Last seen 2 hours ago</p>
</div>
// Anchor
<button aria-describedby={tooltipId}>@username</button>

// Dialog: interactive card (use click, not hover)
<div role="dialog" aria-label="User profile" aria-modal="false">
  <p>User bio...</p>
  <button>Follow</button>
</div>
```

Never put interactive elements inside a `role="tooltip"`—screen readers won't navigate to them because tooltips are not meant to receive focus.

## Touch Devices

Hover doesn't exist on touch. `floating-ui`'s `useHover` skips the hover interaction automatically on touch devices (pointer type `touch`). Add tap-to-open behavior:

```ts
const click = useClick(context, { enabled: isTouchDevice() });
const { getReferenceProps } = useInteractions([hover, click, focus]);
```

Or detect pointer capability:

```ts
function isTouchDevice() {
  return window.matchMedia('(hover: none)').matches;
}
```

On touch, the card should close on tap outside (handled by `floating-ui`'s `useDismiss` interaction).

## Portal Rendering

Always render the card in a portal (`FloatingPortal` or `createPortal`). Without a portal, `overflow: hidden` on any ancestor clips the card, and `z-index` stacking contexts cause the card to appear behind other content. The portal ensures the card renders at the document body level.

## Key Rules

- **150ms open delay, 100ms close delay**—asymmetric delays prevent flash and grace-period exits.
- **Cancel close when cursor enters the card**—allows movement from anchor to card.
- **Use `floating-ui`'s `useHover`**—don't manage timers manually.
- **`role="tooltip"` for non-interactive content** only; use `role="dialog"` + click trigger for interactive cards.
- **`FloatingPortal`**—never render hover cards in the DOM subtree of the anchor.
- **Touch: fallback to tap**—`useHover` skips on touch; add `useClick` for touch support.
- **`move: false`** on `useHover`—prevents re-triggering open when cursor moves within the anchor.
