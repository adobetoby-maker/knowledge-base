# Pattern: Slide-Over Panel

## What This Solves

A slide-over is a side panel that animates in from the edge of the screen and overlays the content without pushing it. It's appropriate for: detail views, editing forms, filter panels, and secondary navigation that the user should be able to dismiss without losing the context of the page behind it. The key distinction from a drawer that pushes content is that the main content remains visible and partially interactive-feeling.

## Why Headless UI Transition

Headless UI's `<Transition>` + `<Dialog>` combo handles: focus trap, ARIA attributes, escape key, scroll lock, and portal rendering. Building this manually introduces subtle bugs — especially around focus management during enter/leave animations.

```tsx
import { Dialog, Transition } from '@headlessui/react'
import { Fragment } from 'react'

interface SlideOverProps {
  open: boolean
  onClose: () => void
  title: string
  children: React.ReactNode
  side?: 'left' | 'right'
}

export function SlideOver({
  open,
  onClose,
  title,
  children,
  side = 'right',
}: SlideOverProps) {
  return (
    <Transition.Root show={open} as={Fragment}>
      <Dialog as="div" className="relative z-50" onClose={onClose}>

        {/* Backdrop */}
        <Transition.Child
          as={Fragment}
          enter="ease-in-out duration-300"
          enterFrom="opacity-0"
          enterTo="opacity-100"
          leave="ease-in-out duration-300"
          leaveFrom="opacity-100"
          leaveTo="opacity-0"
        >
          <div className="fixed inset-0 bg-black/40 transition-opacity" />
        </Transition.Child>

        {/* Panel */}
        <div className={cn(
          'fixed inset-y-0 flex max-w-full',
          side === 'right' ? 'right-0 pl-10' : 'left-0 pr-10'
        )}>
          <Transition.Child
            as={Fragment}
            enter="transform transition ease-in-out duration-300"
            enterFrom={side === 'right' ? 'translate-x-full' : '-translate-x-full'}
            enterTo="translate-x-0"
            leave="transform transition ease-in-out duration-300"
            leaveFrom="translate-x-0"
            leaveTo={side === 'right' ? 'translate-x-full' : '-translate-x-full'}
          >
            <Dialog.Panel className="w-screen max-w-md bg-background shadow-xl flex flex-col">
              <div className="flex items-center justify-between px-4 py-4 border-b">
                <Dialog.Title className="text-base font-semibold">
                  {title}
                </Dialog.Title>
                <button
                  onClick={onClose}
                  className="rounded-md p-1 text-muted-foreground hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  aria-label="Close panel"
                >
                  <XIcon className="h-5 w-5" />
                </button>
              </div>

              <div className="flex-1 overflow-y-auto px-4 py-6">
                {children}
              </div>
            </Dialog.Panel>
          </Transition.Child>
        </div>
      </Dialog>
    </Transition.Root>
  )
}
```

## Backdrop Click to Close

Headless UI's `<Dialog onClose={onClose}>` handles backdrop clicks automatically — clicking the dim overlay fires `onClose`. Do not add a separate click handler to the backdrop div. If you want to disable backdrop-click-to-close (for unsaved forms), pass a no-op: `<Dialog onClose={() => {}}>`

## Focus Management

Headless UI focuses the first focusable element in the panel when it opens and returns focus to the trigger when it closes. Override initial focus with `initialFocus`:

```tsx
const closeBtnRef = useRef<HTMLButtonElement>(null)

<Dialog initialFocus={closeBtnRef} ...>
  <button ref={closeBtnRef} onClick={onClose}>Close</button>
```

This is useful for panels that open from a data table row — you don't want focus jumping to the middle of a form.

## Stacked Slide-Overs

When a second slide-over opens over the first (e.g., a detail panel opens an edit form), offset the second one visually:

```tsx
// Each additional level shifts inward
const levelOffset = level * 16  // pixels
<div style={{ right: levelOffset }} className="fixed inset-y-0 ...">
```

Use a context or store to track the stack depth. Each panel reads its own level. On close, the level decrements and the panel below becomes active.

## Z-Index Management

Assign z-index by level, not by hard-coded values. Base z-index at 50 per level:

```ts
const zIndex = 50 + (level * 10)
// Level 0: z-50, Level 1: z-[60], Level 2: z-[70]
```

This ensures panels always stack correctly regardless of insertion order.

## Scroll Lock

Headless UI applies `overflow: hidden` to `<body>` automatically when the dialog is open, preventing the background from scrolling. Do not manually set this.

## Key Rules

- Use Headless UI `<Dialog>` + `<Transition>` — never build focus trap or escape handling manually
- The backdrop close is handled by `<Dialog onClose>` — do not add a separate onClick to the backdrop element
- For panels with unsaved forms, pass a no-op to `onClose` and handle close via an explicit button with a confirmation dialog
- Animate backdrop and panel on separate `<Transition.Child>` elements so they can have different timing
- Keep max-width at `max-w-md` (448px) for detail views; `max-w-lg` or `max-w-xl` for edit forms
- Overflow the inner content area, not the panel itself: `flex-col` container, `flex-1 overflow-y-auto` on the content div
