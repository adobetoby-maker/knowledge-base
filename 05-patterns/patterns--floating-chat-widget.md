# Pattern: Floating Chat Widget

## Overview
A floating chat widget must sit at a fixed position without conflicting with other page elements, survive scroll and layout changes, and work correctly on mobile where screen real estate is scarce. The main engineering challenges are z-index stacking conflicts, keyboard/viewport push-up on mobile, and the widget interfering with other fixed UI like cookie banners or floating action buttons.

## Implementation

### Base structure using a portal

```tsx
import { createPortal } from 'react-dom'

function FloatingChatWidget() {
  const [isOpen, setIsOpen] = useState(false)
  const [unread, setUnread] = useState(0)
  const [mounted, setMounted] = useState(false)

  // Must mount client-side — portals don't work during SSR
  useEffect(() => { setMounted(true) }, [])
  if (!mounted) return null

  return createPortal(
    <div className="fixed bottom-4 right-4 z-[9999] flex flex-col items-end gap-3">
      {isOpen && <ChatPanel onClose={() => setIsOpen(false)} />}
      <ChatTriggerButton
        isOpen={isOpen}
        unread={unread}
        onClick={() => { setIsOpen(o => !o); setUnread(0) }}
      />
    </div>,
    document.body
  )
}
```

### Trigger button with unread badge

```tsx
function ChatTriggerButton({ isOpen, unread, onClick }: Props) {
  return (
    <button
      onClick={onClick}
      aria-label={isOpen ? 'Close chat' : `Open chat${unread ? `, ${unread} unread` : ''}`}
      className="relative w-14 h-14 rounded-full bg-blue-600 text-white shadow-lg
                 hover:bg-blue-700 active:scale-95 transition-all"
    >
      {isOpen ? <X size={24} /> : <MessageCircle size={24} />}
      {!isOpen && unread > 0 && (
        <span className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-red-500 
                         text-xs font-bold flex items-center justify-center">
          {unread > 9 ? '9+' : unread}
        </span>
      )}
    </button>
  )
}
```

### Chat panel

```tsx
function ChatPanel({ onClose }: { onClose: () => void }) {
  return (
    <div
      className="w-80 sm:w-96 h-[480px] max-h-[80vh] bg-white rounded-2xl shadow-2xl 
                 border border-gray-200 flex flex-col overflow-hidden"
      // Prevent clicks inside panel from closing it
      onClick={(e) => e.stopPropagation()}
    >
      <div className="flex items-center justify-between px-4 py-3 border-b bg-blue-600 text-white">
        <span className="font-semibold">Support</span>
        <button onClick={onClose} aria-label="Close chat"><X size={18} /></button>
      </div>
      <div className="flex-1 overflow-y-auto p-4">
        {/* Message list */}
      </div>
      <div className="border-t p-3">
        <ChatInput />
      </div>
    </div>
  )
}
```

### Mobile: minimize on scroll

```tsx
function useMobileScrollMinimize(isOpen: boolean, setIsOpen: (v: boolean) => void) {
  useEffect(() => {
    if (!isOpen) return

    let lastY = window.scrollY
    const handler = () => {
      const delta = Math.abs(window.scrollY - lastY)
      // Only minimize on significant scroll (not rubber-band bounce)
      if (delta > 80 && window.innerWidth < 640) {
        setIsOpen(false)
      }
      lastY = window.scrollY
    }

    window.addEventListener('scroll', handler, { passive: true })
    return () => window.removeEventListener('scroll', handler)
  }, [isOpen, setIsOpen])
}
```

### Third-party iframe embed (Intercom, Crisp, etc.)

```tsx
// Load lazily — don't block page load for a chat widget
function IntercomWidget() {
  useEffect(() => {
    // Only load when user is likely to interact
    const load = () => {
      window.Intercom('boot', { app_id: process.env.NEXT_PUBLIC_INTERCOM_APP_ID })
      window.removeEventListener('mousemove', load)
      window.removeEventListener('touchstart', load)
    }
    window.addEventListener('mousemove', load, { once: true })
    window.addEventListener('touchstart', load, { once: true })
  }, [])
  return null
}
```

### Avoiding z-index conflicts

```css
/* Establish a stacking context at the app level */
#__next { isolation: isolate; }

/* Widget always wins over app content but loses to system dialogs */
.chat-widget { z-index: 9999; }
.modal-overlay { z-index: 10000; } /* Modals appear above chat */
.cookie-banner { z-index: 9998; }  /* Chat overlaps cookie banner */
```

## Key Rules
- Use `createPortal` to render into `document.body` — avoids stacking context traps
- Never render the portal during SSR — check `mounted` state first
- Bottom-right is convention; don't use bottom-left (interferes with cookie banners)
- On mobile, account for the virtual keyboard pushing the viewport — widget should not overlap form inputs
- Lazy-load third-party widget scripts (use interaction-based loading, not immediate)
- Unread count should clear when the panel is opened
- Provide a keyboard shortcut (e.g., `?` or `Shift+/`) to open the chat for accessibility
- Avoid animating with `transform` on the fixed container — it creates a new stacking context
