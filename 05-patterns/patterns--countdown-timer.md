# Pattern: Countdown Timer

## What This Solves

Countdown timers appear in sales countdowns, event launch pages, limited-time offers, and session expiry warnings. Two variants: display-only countdown to a future datetime, and interactive session timer with a warning state.

## Countdown to Future Date

```tsx
// components/CountdownTimer.tsx
'use client'
import { useState, useEffect } from 'react'

interface TimeLeft {
  days: number
  hours: number
  minutes: number
  seconds: number
  expired: boolean
}

function getTimeLeft(targetDate: Date): TimeLeft {
  const diff = targetDate.getTime() - Date.now()
  if (diff <= 0) return { days: 0, hours: 0, minutes: 0, seconds: 0, expired: true }

  return {
    days: Math.floor(diff / (1000 * 60 * 60 * 24)),
    hours: Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60)),
    minutes: Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60)),
    seconds: Math.floor((diff % (1000 * 60)) / 1000),
    expired: false,
  }
}

interface CountdownTimerProps {
  targetDate: Date
  onExpire?: () => void
  showDays?: boolean
}

export function CountdownTimer({ targetDate, onExpire, showDays = true }: CountdownTimerProps) {
  const [timeLeft, setTimeLeft] = useState<TimeLeft>(() => getTimeLeft(targetDate))

  useEffect(() => {
    if (timeLeft.expired) {
      onExpire?.()
      return
    }

    const id = setInterval(() => {
      const next = getTimeLeft(targetDate)
      setTimeLeft(next)
      if (next.expired) {
        clearInterval(id)
        onExpire?.()
      }
    }, 1000)

    return () => clearInterval(id)
  }, [targetDate, timeLeft.expired, onExpire])

  if (timeLeft.expired) {
    return <span className="text-muted-foreground text-sm">Offer expired</span>
  }

  const segments = showDays
    ? [
        { label: 'Days', value: timeLeft.days },
        { label: 'Hours', value: timeLeft.hours },
        { label: 'Min', value: timeLeft.minutes },
        { label: 'Sec', value: timeLeft.seconds },
      ]
    : [
        { label: 'Hours', value: timeLeft.hours + timeLeft.days * 24 },
        { label: 'Min', value: timeLeft.minutes },
        { label: 'Sec', value: timeLeft.seconds },
      ]

  return (
    <div className="flex items-center gap-2" role="timer" aria-live="off">
      {segments.map((seg, i) => (
        <div key={seg.label} className="flex items-center gap-2">
          <div className="text-center">
            <div className="tabular-nums text-2xl font-bold leading-none">
              {String(seg.value).padStart(2, '0')}
            </div>
            <div className="text-xs text-muted-foreground uppercase tracking-wide">
              {seg.label}
            </div>
          </div>
          {i < segments.length - 1 && (
            <span className="text-2xl font-bold text-muted-foreground pb-3">:</span>
          )}
        </div>
      ))}
    </div>
  )
}
```

Usage:
```tsx
const saleEnds = new Date('2026-01-01T00:00:00Z')

<CountdownTimer
  targetDate={saleEnds}
  onExpire={() => {
    // Re-fetch to update UI when sale ends
    queryClient.invalidateQueries({ queryKey: ['sale-prices'] })
  }}
/>
```

## Session Expiry Warning

```tsx
'use client'
import { useState, useEffect, useRef } from 'react'
import { toast } from 'sonner'

interface SessionTimerProps {
  sessionDurationMs: number   // total session length
  warningMs?: number          // show warning when this many ms remain
  onExpire: () => void        // called when session ends — typically sign out
}

export function useSessionTimer({ sessionDurationMs, warningMs = 5 * 60 * 1000, onExpire }: SessionTimerProps) {
  const [remainingMs, setRemainingMs] = useState(sessionDurationMs)
  const warned = useRef(false)

  useEffect(() => {
    const id = setInterval(() => {
      setRemainingMs(prev => {
        const next = prev - 1000
        if (next <= 0) {
          clearInterval(id)
          onExpire()
          return 0
        }
        if (next <= warningMs && !warned.current) {
          warned.current = true
          toast.warning(`Your session expires in ${Math.ceil(next / 60000)} minutes`)
        }
        return next
      })
    }, 1000)
    return () => clearInterval(id)
  }, [])

  return {
    remainingMs,
    minutes: Math.floor(remainingMs / 60000),
    seconds: Math.floor((remainingMs % 60000) / 1000),
  }
}
```

## SSR Hydration Note

The initial server-rendered value and the client-rendered value will differ by the server-to-client time gap. Use `suppressHydrationWarning` on the timer element, or render it only after hydration:

```tsx
const [mounted, setMounted] = useState(false)
useEffect(() => setMounted(true), [])
if (!mounted) return <span className="tabular-nums">Loading...</span>
```

## tabular-nums for Smooth Counting

Always apply `tabular-nums` (CSS `font-variant-numeric: tabular-nums`) to timer digits. Without it, the layout shifts on every second tick as digit widths change (e.g., "9" vs "10" in variable-width fonts).
