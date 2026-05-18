# Avatar Group — Overlapping Avatar Stack

## Negative Margin Stacking

Avatars overlap via negative left margin on every item after the first. The outermost container uses `flex` — negative margin pulls each subsequent avatar under its predecessor.

```tsx
<div className="flex items-center">
  {visible.map((user, i) => (
    <div
      key={user.id}
      className="relative"
      style={{ marginLeft: i === 0 ? 0 : '-8px' }}
    >
      <Avatar user={user} size={32} className="ring-2 ring-background" />
    </div>
  ))}
  {overflow > 0 && <OverflowBadge count={overflow} />}
</div>
```

The `ring-2 ring-background` creates a white (or background-colored) border around each avatar that visually separates stacked items without requiring actual margin. This adapts automatically to dark mode — `ring-background` picks up the CSS variable.

## Z-Index: Left Avatar on Top

By default, later DOM elements stack on top due to stacking context order. For an avatar group, the **first** avatar (leftmost) should be on top — it's the most important (or the "you" avatar). Reverse the z-index:

```tsx
style={{ zIndex: visible.length - i }}
```

This gives index 0 the highest z-index. Without this, hovering near the left edge shows the wrong avatar's tooltip.

## Max Visible Count with "+N More"

Never render all avatars — cap at 4-5 visible and show a count badge. The badge is an avatar-shaped div, not a floating pill, so spacing is consistent.

```tsx
const MAX = 4
const visible = members.slice(0, MAX)
const overflow = members.length - MAX

function OverflowBadge({ count }: { count: number }) {
  return (
    <div
      className="relative flex items-center justify-center rounded-full bg-muted text-muted-foreground text-xs font-medium ring-2 ring-background"
      style={{ width: 32, height: 32, marginLeft: '-8px', zIndex: 0 }}
      aria-label={`${count} more members`}
    >
      +{count > 99 ? '99' : count}
    </div>
  )
}
```

Show "+N" not "N+" — reads as "plus N more" rather than "N or more."

## Tooltip on Hover

Each visible avatar shows a tooltip with the member's full name. For the overflow badge, the tooltip lists all hidden names, comma-separated or in a small list.

```tsx
<Tooltip content={user.name}>
  <div style={{ zIndex: visible.length - i }}>
    <Avatar user={user} />
  </div>
</Tooltip>

// Overflow tooltip
<Tooltip content={hidden.map(u => u.name).join(', ')}>
  <OverflowBadge count={overflow} />
</Tooltip>
```

Keep tooltip content concise — names only. Adding role/email to the tooltip makes it overflow the viewport on narrow screens.

## Sizing

Avatar size determines the negative margin — rule of thumb: overlap by 25% of avatar diameter. For 32px avatars: `-8px` margin. For 24px: `-6px`. For 40px: `-10px`. Don't hard-code `-8px` everywhere.

```ts
const overlap = (size: number) => `-${Math.round(size * 0.25)}px`
```

## Key Rules

- `ring-2 ring-background` separates avatars without real margins — adapts to dark mode.
- Reverse z-index (`length - i`) so the leftmost avatar sits on top.
- Cap visible count at 4–5; render an avatar-shaped "+N" badge for overflow.
- Overflow tooltip lists all hidden names, not just the count.
- Overlap = 25% of avatar diameter — derive from size, don't hard-code.
