# failure--text-overflow-hidden.md

`overflow: hidden` on a parent does more than clip children — it creates a new stacking context and, in some cases, a new block formatting context. Content that appears correctly in isolation suddenly disappears or gets clipped unexpectedly when a parent gets `overflow: hidden` added to it.

## Why This Happens More Than It Should

Developers add `overflow: hidden` to fix unrelated problems: clearing floats, preventing content from visually bleeding past a border-radius, or hiding a scroll bar. The side effects on positioning and stacking are invisible until a dropdown, tooltip, or sticky element breaks.

## Z-Index Clipping

`overflow: hidden` clips absolutely positioned children that overflow the parent's bounds, regardless of `z-index`. A child with `z-index: 9999` positioned outside the parent's box will still be clipped. Z-index controls paint order between stacking contexts — it doesn't escape parent overflow.

This is the number-one cause of "my dropdown disappears behind the page." The dropdown is inside a container with `overflow: hidden`. Raising its z-index won't fix it. The fix is to portal the dropdown to the document body or to a container that doesn't clip.

## Sticky Positioning Is Killed by Overflow: Hidden

`position: sticky` requires that the scroll container be an ancestor of the sticky element. When any ancestor has `overflow: hidden` (or `overflow: auto`/`scroll` on an axis), the browser treats that element as the scroll container. If that container doesn't scroll, sticky stops working — the element just acts like `position: relative`.

Check for hidden `overflow` in your DOM tree before debugging sticky. The fix is removing `overflow: hidden` from the ancestor or restructuring so the sticky element's scroll container is the element that actually scrolls.

## Dropdowns and Tooltips Need Portals

Any component that positions itself relative to a trigger but renders content outside the trigger's bounds — dropdowns, comboboxes, tooltips, date pickers — will be clipped if the trigger lives inside an `overflow: hidden` container. The React pattern to escape this is portaling:

```tsx
import { createPortal } from 'react-dom';

// Render the dropdown content into document.body, not into the trigger's parent tree
createPortal(<DropdownMenu />, document.body)
```

Calculate position using `getBoundingClientRect()` on the trigger element, then position the portal content with fixed positioning relative to those coordinates. This completely escapes the overflow clipping hierarchy.

## Border-Radius and the Hidden Overflow Trap

Adding `border-radius` to a container rounds its corners visually but doesn't clip children. The common fix is adding `overflow: hidden` to force the rounding to clip children as well. This works but silently breaks any child that tries to overflow the container — dropdowns, sticky children, absolutely-positioned overlays.

Prefer `clip-path` on the container or adding `border-radius` directly to children when you need rounding without clipping.

## Diagnosing Clipped Content

In browser DevTools: select the clipped element, inspect its ancestor chain, and look for any ancestor with `overflow` not set to `visible`. That's your culprit. The "Computed" styles panel shows the resolved `overflow` value — look for the element where it changes from `visible` to anything else.

## Key Rules

- `overflow: hidden` clips absolutely-positioned children that overflow the bounds — z-index cannot rescue them.
- `position: sticky` breaks silently when any ancestor has non-`visible` overflow.
- Dropdown, tooltip, and popover content must be portaled to escape overflow-clipping ancestors.
- Adding `overflow: hidden` to fix border-radius clipping is a trap — use `clip-path` on the container or `border-radius` on children instead.
- Always inspect the full ancestor chain for overflow before debugging z-index or sticky positioning.
