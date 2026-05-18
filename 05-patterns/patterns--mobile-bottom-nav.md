# Mobile Bottom Navigation Bar

## Item Count: 4–5 Max

4 items is ideal. 5 is acceptable. Never 6+ — icons become too small, labels truncate, and it breaks the visual rhythm. If you have more than 5 destinations, use a "More" tab that opens a full-screen menu.

Each item must have both an icon and a label. Icon-only navigation fails accessibility and usability: users can't decode what an abstract icon means without a label, especially in a new app.

## Structure and ARIA

```tsx
<nav aria-label="Main navigation" className="fixed bottom-0 inset-x-0">
  <div className="flex items-end pb-safe bg-background border-t">
    {tabs.map(tab => (
      <Link
        key={tab.href}
        href={tab.href}
        aria-current={isActive(tab.href) ? 'page' : undefined}
        className={cn(
          "flex flex-col items-center gap-0.5 flex-1 py-2 text-xs",
          isActive(tab.href) ? "text-primary" : "text-muted-foreground"
        )}
      >
        <div className="relative">
          <tab.Icon className="w-6 h-6" aria-hidden="true" />
          {tab.badge > 0 && (
            <span className="absolute -top-1 -right-1 h-4 min-w-4 px-0.5 rounded-full bg-destructive text-destructive-foreground text-[10px] flex items-center justify-center">
              {tab.badge > 99 ? '99+' : tab.badge}
            </span>
          )}
        </div>
        <span>{tab.label}</span>
      </Link>
    ))}
  </div>
</nav>
```

Use `<nav>` not `<div>` — creates a landmark region. `aria-current="page"` on the active tab communicates current location to screen readers (not `aria-selected` — that's for listboxes).

## Safe Area Inset (`pb-safe`)

The iPhone home indicator sits at the bottom of the screen. Without safe area padding, tab items overlap it and become hard to tap.

```css
/* In globals.css */
.pb-safe {
  padding-bottom: env(safe-area-inset-bottom);
}
/* Or with Tailwind plugin: */
/* Use tailwind-safe-area or manual: pb-[env(safe-area-inset-bottom)] */
```

The nav background color must extend behind the home indicator too — use `fixed bottom-0` so it does. Without this, you get a jarring gap between the nav and the screen edge.

## Active Indicator Design

Two valid patterns:

1. **Icon swap** — filled icon when active, outline when inactive. Most common, immediately understood.
2. **Underline / top border** — a 2px colored line above or below the active icon. Clean and clear.

Avoid: background color fills behind the whole tab item — they look like buttons, not navigation. Avoid: animated dots or badges on the active state — confusing with notification badges.

## Badge Count on Tab Icon

The badge position is `absolute -top-1 -right-1` relative to the icon's bounding box — not relative to the tab item. This keeps it visually associated with the icon, not floating in the label area. Use `min-w-4` not `w-4` so the badge expands for 2-digit numbers.

## Layout Shift Prevention

The bottom nav takes up real vertical space. The page content must have `pb` padding equal to the nav height + safe area inset, otherwise content hides behind the nav:

```tsx
<main className="pb-[calc(4rem+env(safe-area-inset-bottom))]">
  {children}
</main>
```

## Key Rules

- 4 items ideal, 5 max. Never icon-only — always show labels.
- `<nav aria-label="Main navigation">` creates a landmark; `aria-current="page"` marks active tab.
- `pb-safe` (env safe-area-inset-bottom) prevents overlap with iPhone home bar.
- Nav background extends to screen edge — use `fixed bottom-0`, not `sticky`.
- Badge is positioned relative to the icon, not the tab — use `absolute -top-1 -right-1`.
- Page content needs bottom padding matching nav height + safe area or content hides under nav.
