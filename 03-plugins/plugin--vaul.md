# Plugin: Vaul (Drawer)

## Overview

Vaul is a drawer component built on Radix primitives. It provides the mobile-native snap-point drawer pattern: pull up from the bottom, drag to dismiss, multiple snap heights. The key differentiator from a plain bottom sheet: drag velocity detection and spring physics feel native rather than CSS-transition-based.

## Install

```bash
npm install vaul
```

## Basic Drawer

```tsx
import { Drawer } from 'vaul'

export function MobileMenu() {
  return (
    <Drawer.Root>
      <Drawer.Trigger asChild>
        <button className="md:hidden">Menu</button>
      </Drawer.Trigger>
      <Drawer.Portal>
        <Drawer.Overlay className="fixed inset-0 bg-black/40" />
        <Drawer.Content className="bg-white flex flex-col rounded-t-[10px] fixed bottom-0 left-0 right-0 max-h-[96vh]">
          {/* Drag handle */}
          <div className="p-4 bg-white rounded-t-[10px] flex-shrink-0">
            <div className="mx-auto w-12 h-1.5 rounded-full bg-gray-300 mb-4" />
            <Drawer.Title className="text-lg font-semibold">Menu</Drawer.Title>
          </div>
          {/* Scrollable content */}
          <div className="p-4 overflow-y-auto">
            <nav className="space-y-2">
              <a href="/">Home</a>
              <a href="/about">About</a>
            </nav>
          </div>
        </Drawer.Content>
      </Drawer.Portal>
    </Drawer.Root>
  )
}
```

## Snap Points

```tsx
<Drawer.Root snapPoints={[0.4, 1]} defaultSnapPoint={0.4}>
  <Drawer.Content className="fixed bottom-0 left-0 right-0 bg-white rounded-t-2xl"
    style={{ height: 'var(--snap-point-height, 96vh)' }}>
    {/* Content grows with snap height */}
  </Drawer.Content>
</Drawer.Root>
```

`snapPoints` accepts fractions of viewport height (0.4 = 40vh) or pixel values as strings ('400px'). The drawer snaps to the nearest point on release. Drag past the lowest snap point to dismiss.

## Controlled Open State

```tsx
function FilterDrawer({ open, onClose }: { open: boolean; onClose: () => void }) {
  return (
    <Drawer.Root open={open} onOpenChange={(v) => !v && onClose()}>
      <Drawer.Portal>
        <Drawer.Overlay className="fixed inset-0 bg-black/40 z-40" />
        <Drawer.Content className="fixed bottom-0 inset-x-0 bg-white rounded-t-2xl z-50 p-6 pb-safe">
          <Drawer.Title className="text-lg font-semibold mb-4">Filters</Drawer.Title>
          {/* filter controls */}
          <button onClick={onClose} className="w-full btn-primary mt-4">Apply</button>
        </Drawer.Content>
      </Drawer.Portal>
    </Drawer.Root>
  )
}
```

## Direction: Right/Left/Top

```tsx
<Drawer.Root direction="right">
  <Drawer.Content className="fixed inset-y-0 right-0 w-80 bg-white shadow-xl">
    {/* Side drawer — no snap points, just slide in/out */}
  </Drawer.Content>
</Drawer.Root>
```

Vaul v0.9+ supports `direction` prop: `'bottom'` (default), `'top'`, `'left'`, `'right'`. Direction 'right'/'left' renders as a standard side sheet without snap behavior.

## Nested Drawers

```tsx
<Drawer.Root>
  <Drawer.Content>
    <Drawer.NestedRoot>
      <Drawer.Trigger>Open nested</Drawer.Trigger>
      <Drawer.Content>
        {/* Opens on top of parent drawer */}
      </Drawer.Content>
    </Drawer.NestedRoot>
  </Drawer.Content>
</Drawer.Root>
```

Use `Drawer.NestedRoot` (not `Drawer.Root`) inside a drawer content — this prevents the parent drawer from being dismissed when interacting with the nested one.

## Safe Area Insets (iOS Notch/Home Bar)

```tsx
// Tailwind plugin: tailwindcss-safe-area
<Drawer.Content className="pb-safe px-4 pt-4">

// Or with custom CSS
<Drawer.Content style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}>
```

Without bottom safe area, content is hidden behind the iPhone home indicator.

## Scrollable Content Inside Drawer

```tsx
<Drawer.Content className="fixed bottom-0 inset-x-0 flex flex-col bg-white rounded-t-2xl max-h-[90vh]">
  <div className="p-4 flex-shrink-0">
    <Drawer.Title>Title</Drawer.Title>
  </div>
  {/* overflow-y-auto + flex-1 = fills remaining height and scrolls */}
  <div className="overflow-y-auto flex-1 px-4 pb-4">
    {/* long list */}
  </div>
</Drawer.Content>
```

Vaul handles touch events on the drag handle only. Content inside the scrollable div scrolls normally without accidentally dismissing the drawer.

## Key Rules

- The drag handle div (`w-12 h-1.5 bg-gray-300 mx-auto`) is cosmetic only — Vaul makes the entire header draggable automatically.
- `Drawer.Title` is required for accessibility (`aria-label` on the dialog region). Hidden with `className="sr-only"` if no visible title is appropriate.
- `pb-safe` / `env(safe-area-inset-bottom)` is required on iOS — omitting it hides CTAs behind the home bar.
- For bottom drawers, set `max-h-[96vh]` (not `100vh`) — 96vh leaves a visible gap at top that signals dismissibility.
- `Drawer.NestedRoot` is required for nested drawers — using `Drawer.Root` inside another `Drawer.Root` breaks parent dismiss behavior.
