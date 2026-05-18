# Pattern: Bottom Sheet (Mobile Drawer)

## Overview

Modal overlay that slides up from the bottom of the screen. Mobile-native pattern — better than full modals on small screens because thumb reach is at the bottom. Key requirements: drag-to-dismiss, backdrop dismiss, snap points, and scroll locking.

## Using vaul (Drawer Primitive)

```tsx
import { Drawer } from 'vaul'

function BottomSheet({
  open,
  onClose,
  title,
  children,
}: {
  open: boolean
  onClose: () => void
  title: string
  children: React.ReactNode
}) {
  return (
    <Drawer.Root open={open} onClose={onClose}>
      <Drawer.Portal>
        <Drawer.Overlay
          className="fixed inset-0 bg-black/40 z-40"
          onClick={onClose}
        />
        <Drawer.Content className="fixed bottom-0 left-0 right-0 z-50 bg-white rounded-t-2xl focus:outline-none">
          {/* Drag handle */}
          <div className="mx-auto mt-3 mb-4 h-1.5 w-12 rounded-full bg-gray-300" />
          <div className="px-4 pb-6">
            <Drawer.Title className="text-lg font-semibold mb-4">{title}</Drawer.Title>
            {children}
          </div>
        </Drawer.Content>
      </Drawer.Portal>
    </Drawer.Root>
  )
}
```

vaul handles drag-to-dismiss, velocity detection, and snap points natively.

## Snap Points

For sheets with partial and full states:

```tsx
<Drawer.Root
  snapPoints={[0.4, 1]}
  activeSnapPoint={activeSnap}
  setActiveSnapPoint={setActiveSnap}
>
```

`0.4` = 40% of screen height, `1` = full height. User can drag between snap points.

## Scroll Locking

When the sheet is open and the content inside is scrollable, you need to prevent the page from scrolling while also allowing the sheet content to scroll:

```tsx
useEffect(() => {
  if (open) {
    document.body.style.overflow = 'hidden'
  } else {
    document.body.style.overflow = ''
  }
  return () => { document.body.style.overflow = '' }
}, [open])
```

vaul handles this automatically — only do it manually if not using vaul.

## Custom Implementation (No Library)

```tsx
function BottomSheet({ open, onClose, children }: BottomSheetProps) {
  const sheetRef = useRef<HTMLDivElement>(null)
  const dragStart = useRef(0)
  const [dragY, setDragY] = useState(0)

  function handlePointerDown(e: React.PointerEvent) {
    dragStart.current = e.clientY
    sheetRef.current?.setPointerCapture(e.pointerId)
  }

  function handlePointerMove(e: React.PointerEvent) {
    const dy = Math.max(0, e.clientY - dragStart.current)  // Only downward drag
    setDragY(dy)
  }

  function handlePointerUp() {
    if (dragY > 100) {
      onClose()
    }
    setDragY(0)
  }

  return (
    <>
      {open && <div className="fixed inset-0 bg-black/40 z-40" onClick={onClose} />}
      <div
        ref={sheetRef}
        className={`fixed bottom-0 left-0 right-0 z-50 bg-white rounded-t-2xl transition-transform ${
          open ? 'translate-y-0' : 'translate-y-full'
        }`}
        style={{ transform: open ? `translateY(${dragY}px)` : 'translateY(100%)' }}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
      >
        {/* Content */}
      </div>
    </>
  )
}
```

## When to Use Bottom Sheet vs Modal

| Bottom sheet | Modal |
|---|---|
| Mobile-primary UIs | Desktop or desktop-first |
| Action menus, filter panels | Confirmation dialogs |
| Share options, context menus | Form entry |
| Quick edit inline | Complex multi-step flows |

## Key Rules

- Always show a drag handle (short horizontal line at top) so users know the sheet is draggable.
- Drag-to-dismiss threshold: ~100px downward drag or velocity > 0.5 before releasing.
- For content-heavy sheets (long lists), make only the header draggable — content area should scroll without triggering dismiss.
- Avoid using bottom sheets for critical confirmations (delete, payment) — too easy to accidentally dismiss.
