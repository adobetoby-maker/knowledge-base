# Pattern: Floating Action Button (FAB)

## What This Solves

A FAB is a persistent button anchored to the bottom-right corner of the viewport, used for the primary action on a page (new invoice, compose message, add item). It remains visible as the user scrolls. The challenge is: not obscuring important content, hiding on keyboard-open mobile, and providing an accessible label.

## Basic FAB

```tsx
// components/FloatingActionButton.tsx
import { Plus } from 'lucide-react'
import { cn } from '@/lib/utils'

interface FabProps {
  onClick: () => void
  icon?: React.ReactNode
  label: string          // Required — used as aria-label
  variant?: 'default' | 'destructive'
  className?: string
}

export function FloatingActionButton({
  onClick,
  icon = <Plus className="h-6 w-6" />,
  label,
  variant = 'default',
  className,
}: FabProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className={cn(
        'fixed bottom-6 right-6 z-30 flex h-14 w-14 items-center justify-center rounded-full shadow-lg transition-transform hover:scale-105 active:scale-95 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2',
        variant === 'default' && 'bg-primary text-primary-foreground',
        variant === 'destructive' && 'bg-destructive text-destructive-foreground',
        className
      )}
    >
      {icon}
    </button>
  )
}
```

## Extended FAB (Label + Icon)

For desktop where there's space to show a text label:

```tsx
export function ExtendedFab({ onClick, label }: { onClick: () => void; label: string }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="fixed bottom-6 right-6 z-30 flex h-14 items-center gap-2 rounded-full bg-primary px-6 text-primary-foreground shadow-lg transition-transform hover:scale-105 active:scale-95 focus:outline-none focus:ring-2 focus:ring-ring"
    >
      <Plus className="h-5 w-5" />
      <span className="text-sm font-medium">{label}</span>
    </button>
  )
}
```

## Speed Dial (Multiple Actions)

```tsx
'use client'
import { useState } from 'react'
import { Plus, X, FileText, User, Building } from 'lucide-react'

interface SpeedDialAction {
  icon: React.ReactNode
  label: string
  onClick: () => void
}

const ACTIONS: SpeedDialAction[] = [
  { icon: <FileText className="h-5 w-5" />, label: 'New invoice', onClick: () => {} },
  { icon: <User className="h-5 w-5" />, label: 'New client', onClick: () => {} },
  { icon: <Building className="h-5 w-5" />, label: 'New service', onClick: () => {} },
]

export function SpeedDial() {
  const [open, setOpen] = useState(false)

  return (
    <div className="fixed bottom-6 right-6 z-30 flex flex-col items-end gap-3">
      {/* Sub-actions (shown when open) */}
      {open && ACTIONS.map((action, i) => (
        <div
          key={i}
          className="flex items-center gap-2"
          style={{ animation: `fadeInUp 150ms ${i * 50}ms both` }}
        >
          <span className="bg-popover border rounded px-2 py-1 text-xs font-medium shadow-sm">
            {action.label}
          </span>
          <button
            type="button"
            onClick={() => { action.onClick(); setOpen(false) }}
            className="flex h-10 w-10 items-center justify-center rounded-full bg-secondary text-secondary-foreground shadow hover:scale-105 transition-transform"
            aria-label={action.label}
          >
            {action.icon}
          </button>
        </div>
      ))}

      {/* Main button */}
      <button
        type="button"
        onClick={() => setOpen(v => !v)}
        aria-label={open ? 'Close actions' : 'Open actions'}
        aria-expanded={open}
        className="flex h-14 w-14 items-center justify-center rounded-full bg-primary text-primary-foreground shadow-lg transition-transform hover:scale-105 active:scale-95"
      >
        <div className={cn('transition-transform duration-200', open && 'rotate-45')}>
          <Plus className="h-6 w-6" />
        </div>
      </button>
    </div>
  )
}
```

## Hiding When Content is Below FAB

```tsx
// Hide FAB when scrolled to bottom (content below might be obscured)
const [visible, setVisible] = useState(true)

useEffect(() => {
  const handleScroll = () => {
    const scrolledToBottom =
      window.innerHeight + window.scrollY >= document.body.scrollHeight - 100
    setVisible(!scrolledToBottom)
  }
  window.addEventListener('scroll', handleScroll, { passive: true })
  return () => window.removeEventListener('scroll', handleScroll)
}, [])
```

## Mobile Keyboard Avoidance

On mobile, when a virtual keyboard opens, the FAB can sit on top of a form input. Use `env(safe-area-inset-bottom)` to handle notched devices:

```css
.fab {
  bottom: calc(1.5rem + env(safe-area-inset-bottom));
}
```

## Position Adjustment

On pages with a bottom tab bar navigation, offset the FAB:
```tsx
<FloatingActionButton
  className="bottom-24"  // 64px tab bar + 24px gap = 88px total
  ...
/>
```
