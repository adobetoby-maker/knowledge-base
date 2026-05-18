# Pattern: Application Top Navigation Header

## Why This Pattern Matters

The header is on every page. Every pixel of cognitive overhead in the header — confusing avatar menu, badge that doesn't update, search that doesn't focus — is multiplied across every page view. It must be immediately scannable, keyboard navigable, and responsive without resorting to cramming everything behind a hamburger.

## Structure

```
[Hamburger | Logo]  [Breadcrumb / Page Title]  [Search]  [Bell]  [Avatar]
```

Left-anchor: sidebar toggle (mobile) and logo/wordmark. Center or left-of-center: breadcrumb or current page title. Right cluster: global search, notification bell, user avatar/menu. The right cluster is always visible; it never collapses behind a hamburger.

## User Menu (Avatar Dropdown)

Use a `Popover` or `DropdownMenu`, not a `<select>`. Trigger is the user's avatar (first letter fallback if no image). Menu items: profile link, settings link, separator, sign out. Show the user's name and email at the top of the menu as non-interactive context — never make the user wonder which account they're on.

```tsx
<DropdownMenu>
  <DropdownMenuTrigger asChild>
    <button aria-label="User menu" className="rounded-full">
      <Avatar src={user.avatarUrl} fallback={user.name[0]} />
    </button>
  </DropdownMenuTrigger>
  <DropdownMenuContent align="end" className="w-56">
    <div className="px-3 py-2">
      <p className="font-medium text-sm">{user.name}</p>
      <p className="text-xs text-muted-foreground">{user.email}</p>
    </div>
    <DropdownMenuSeparator />
    <DropdownMenuItem asChild><Link href="/settings">Settings</Link></DropdownMenuItem>
    <DropdownMenuSeparator />
    <DropdownMenuItem onClick={signOut}>Sign out</DropdownMenuItem>
  </DropdownMenuContent>
</DropdownMenu>
```

## Notification Bell with Badge

See `patterns--badge-counter.md` for full badge implementation. The bell icon opens a notification panel (`Sheet` or `Popover`). Mark all as read when the panel opens — don't make the user click each item. The badge count comes from a live subscription (Supabase realtime or polling) so it updates without refresh.

## Search Bar

Global search in the header should open a command palette (`cmd+k`), not an inline input that competes with form inputs. The header search is a trigger, not the input itself. If the product genuinely needs persistent header search (e-commerce, content sites), use an input that expands on focus with `transition-[width]`.

```tsx
// Header search — opens command palette
<button
  onClick={() => setCommandOpen(true)}
  className="flex items-center gap-2 rounded-md border px-3 py-1.5 text-sm text-muted-foreground"
>
  <Search className="h-4 w-4" />
  <span className="hidden sm:block">Search...</span>
  <kbd className="hidden sm:block text-xs bg-muted px-1.5 rounded">⌘K</kbd>
</button>
```

## Breadcrumb vs Page Title

Use breadcrumbs in deeply nested apps (3+ levels). Use a simple page title for flat apps. Never show both. Breadcrumbs use `aria-label="Breadcrumb"` on the `<nav>` and `aria-current="page"` on the last item.

## Mobile Hamburger Integration

The hamburger is visible only on mobile (`lg:hidden`). It toggles the sidebar overlay (see `patterns--sidebar-layout.md`). Keep it as the leftmost element so thumb reach is easy. Don't put a second hamburger in the sidebar itself — the backdrop click closes it.

## Sticky Behavior

The header is `sticky top-0 z-40 bg-background/95 backdrop-blur`. `backdrop-blur` prevents content from being readable through the header during scroll. `z-40` puts it above content but below modals (`z-50`).

## Key Rules

- Right cluster (avatar, bell) never collapses behind hamburger — always visible
- User menu shows name + email as non-interactive context at top
- Notification panel marks all as read on open, not on individual click
- Header search opens command palette — it is not an inline search input
- Breadcrumbs on deeply nested apps; page title on flat apps — never both
- `sticky top-0 z-40 backdrop-blur` — prevents scroll bleed-through
- Hamburger is `lg:hidden` only; never show it on desktop
