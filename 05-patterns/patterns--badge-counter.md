# Pattern: Notification Badge with Count

## Why This Pattern Matters

A badge is a micro-signal with outsized importance — it tells the user something needs their attention. Getting the threshold wrong (showing "0", clipping at the wrong number, or misplacing the badge) undermines trust in the notification system entirely. The badge should be silent when nothing needs attention and loud when something does.

## Zero Hides the Badge

Never render `0` inside a badge. When count is 0, the badge should not exist in the DOM — not just hidden with `opacity-0` or `visibility:hidden`, but unmounted. This matters because screen readers announce the badge element; a hidden "0 notifications" badge is noise.

```tsx
{count > 0 && (
  <span className="...">
    {count > 99 ? '99+' : count}
  </span>
)}
```

## Maximum Display: 99+

Cap at 99. `100` doesn't fit cleanly in a small circle. `99+` communicates "many" without layout overflow. For some contexts (shopping carts) capping at `9+` is better — cart counts rarely exceed 9 and users understand the overflow faster.

The cap value should be a prop, not hardcoded:

```tsx
function Badge({ count, max = 99 }: { count: number; max?: number }) {
  if (count <= 0) return null;
  const display = count > max ? `${max}+` : count;
  return <span aria-hidden="true" className="...">{display}</span>;
}
```

## Positioning Relative to Trigger Element

The trigger element (icon button) must be `position: relative`. The badge is `absolute` with `top-0 right-0` and a negative translate to overlap the corner:

```tsx
<button className="relative p-2">
  <Bell className="h-5 w-5" />
  <Badge count={unreadCount} className="absolute -top-1 -right-1" />
</button>
```

For larger icons or custom layouts, use `top-1 right-1` instead. The badge should overlap the icon corner, not sit outside the button bounds (which causes clipping in overflow:hidden containers).

## Screen Reader Text

The visual badge is `aria-hidden="true"`. The accessible count is in the button's `aria-label`:

```tsx
<button
  aria-label={`Notifications${unreadCount > 0 ? `, ${unreadCount} unread` : ''}`}
  className="relative p-2"
>
  <Bell className="h-5 w-5" aria-hidden="true" />
  {unreadCount > 0 && (
    <span aria-hidden="true" className="absolute -top-1 -right-1 ...">
      {unreadCount > 99 ? '99+' : unreadCount}
    </span>
  )}
</button>
```

Never put the count text in a `<span>` that a screen reader will announce separately — it creates double-announcement ("3 Notifications 3 unread").

## Dot Badge (No Count)

For simple presence indicators (online status, unread indicator without a count), use a dot badge — 8px circle, no text, positioned identically. Use this when the count is not meaningful (e.g., "there are unread messages in this channel" rather than "there are 7 unread messages"). The `notification-dot.md` file covers this variant in detail.

## Animation

On count increase, briefly scale the badge up (scale 1 → 1.3 → 1 over 300ms). On count reaching 0, fade out before unmounting. Both transitions are cosmetic but communicate liveness.

## Key Rules

- Never render the badge when count is 0 — unmount it entirely
- Cap display at 99+ (or 9+ for cart contexts); make the cap a prop
- Badge is `absolute` on a `relative` wrapper; use negative translate to overlap icon corner
- Badge element is `aria-hidden="true"`; count is in the button's `aria-label`
- Screen reader text reads the total: "Notifications, 3 unread" — not "Bell 3"
- Scale animation on increment communicates liveness
