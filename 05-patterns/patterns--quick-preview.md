# Pattern: Hover/Focus Preview Card

## Overview

A preview card shows additional detail when hovering over or focusing a trigger element — used for user profile previews, link previews, product quick-look. The key requirements: delay before showing (prevents accidental triggers during cursor movement), smart positioning (doesn't clip off screen), keyboard accessibility (shows on focus, dismisses on Escape), and lazy content loading.

## Why a Delay Matters

Without a delay, the preview fires on every element the cursor passes over while moving to another target. A 200-300ms delay is the threshold where intentional hover feels instant but accidental hover is suppressed. Implement the delay in both directions: delay show, but hide immediately on mouse-leave (delayed hide feels sluggish).

## Using floating-ui for Positioning

`@floating-ui/react` handles the math of positioning a floating element relative to a reference without clipping:

```tsx
import {
  useFloating, useHover, useFocus, useDismiss, useInteractions,
  offset, flip, shift, autoUpdate
} from '@floating-ui/react'

function usePreview() {
  const [open, setOpen] = useState(false)

  const { refs, floatingStyles, context } = useFloating({
    open,
    onOpenChange: setOpen,
    placement: 'top',
    whileElementsMounted: autoUpdate,  // Reposition on scroll/resize
    middleware: [
      offset(8),           // Gap between trigger and card
      flip(),              // Flip to bottom if not enough space above
      shift({ padding: 8 }) // Nudge horizontally to stay in viewport
    ],
  })

  const hover = useHover(context, {
    delay: { open: 250, close: 0 },   // Show after 250ms, hide immediately
    move: false,                        // Don't re-trigger while moving within trigger
  })
  const focus = useFocus(context)       // Show on keyboard focus
  const dismiss = useDismiss(context)   // Hide on Escape or outside click

  const { getReferenceProps, getFloatingProps } = useInteractions([hover, focus, dismiss])

  return { open, refs, floatingStyles, getReferenceProps, getFloatingProps }
}
```

## Lazy Content Loading

Don't fetch preview content until the preview is actually opening — not on mount of the trigger element:

```tsx
function UserPreview({ userId, children }: { userId: string; children: React.ReactNode }) {
  const { open, refs, floatingStyles, getReferenceProps, getFloatingProps } = usePreview()

  // Only fetch when preview opens; cache between opens
  const { data: user, isLoading } = useQuery({
    queryKey: ['user-preview', userId],
    queryFn: () => fetchUser(userId),
    enabled: open,   // Key: only runs when open = true
    staleTime: 5 * 60 * 1000,
  })

  return (
    <>
      <span ref={refs.setReference} {...getReferenceProps()}>
        {children}
      </span>

      {open && (
        <div
          ref={refs.setFloating}
          style={floatingStyles}
          role="tooltip"
          {...getFloatingProps()}
          className="z-50 w-64 bg-white border rounded-lg shadow-xl p-4"
        >
          {isLoading ? (
            <PreviewSkeleton />
          ) : user ? (
            <UserPreviewCard user={user} />
          ) : null}
        </div>
      )}
    </>
  )
}
```

`enabled: open` in TanStack Query is the correct pattern — the query fires on the first `open: true` and the result is cached for subsequent opens.

## Keyboard Trigger and Escape Dismiss

`useFocus` from floating-ui handles showing the preview on Tab focus automatically. `useDismiss` handles Escape. No manual key handlers needed when using the floating-ui interaction hooks.

For keyboard users, the preview should be a `role="tooltip"` (if read-only) or `role="dialog"` (if it contains interactive elements like buttons). The distinction matters:
- `role="tooltip"`: non-interactive, closes on focus loss. Do not put buttons inside.
- `role="dialog"`: interactive, needs focus management. Use `useDismiss` + focus trapping.

## Preventing Content Jump on Load

While preview content is loading, show a skeleton at a fixed height matching the expected content. Without a fixed size, the preview card will visibly expand when content loads, which repositioning then tries to compensate for, causing jitter.

```tsx
function PreviewSkeleton() {
  return (
    <div className="space-y-2" style={{ minHeight: 96 }}>
      <div className="flex gap-2">
        <div className="w-10 h-10 rounded-full bg-gray-200 animate-pulse" />
        <div className="flex-1 space-y-1">
          <div className="h-4 w-24 bg-gray-200 rounded animate-pulse" />
          <div className="h-3 w-32 bg-gray-200 rounded animate-pulse" />
        </div>
      </div>
    </div>
  )
}
```

## Key Rules

- Show delay: 200-300ms. Hide delay: 0ms. Reversed feels wrong in both directions.
- Use `@floating-ui/react` for positioning — hand-rolling `getBoundingClientRect` math breaks on scroll, zoom, and transformed ancestors.
- `enabled: open` in the query hook — don't fetch content until the preview actually opens.
- `role="tooltip"` for read-only previews; `role="dialog"` for previews with interactive elements.
- Skeleton height should match expected content height to prevent repositioning jitter on load.
- `move: false` in `useHover` prevents the card from re-triggering when the cursor moves within the trigger element.
