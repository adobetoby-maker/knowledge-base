# Pattern: Relative Time Display

## Overview
Hardcoded relative time strings ("2 minutes ago") go stale and are inconsistent across locales when rendered server-side. Absolute timestamps in `datetime` attributes serve accessibility and machine parsing, while the human-friendly relative form is a client-side enhancement. Without a `setInterval` to update, "2 minutes ago" stays frozen as minutes become hours.

## Implementation

```typescript
// lib/relative-time.ts — threshold-based format selection
// Decides which format to use based on how old the date is

export function getRelativeTimeFormat(date: Date, now = new Date()): string {
  const diffMs = now.getTime() - date.getTime()
  const diffSec = Math.floor(diffMs / 1000)
  const diffMin = Math.floor(diffSec / 60)
  const diffHrs = Math.floor(diffMin / 60)
  const diffDays = Math.floor(diffHrs / 24)

  // < 1 minute: "just now"
  if (diffSec < 60) return 'just now'

  // < 1 hour: "X minutes ago"
  if (diffMin < 60) return formatRelative(diffMin, 'minute')

  // < 24 hours: "X hours ago"
  if (diffHrs < 24) return formatRelative(diffHrs, 'hour')

  // Yesterday
  if (diffDays === 1) return 'yesterday'

  // < 7 days: "X days ago"
  if (diffDays < 7) return formatRelative(diffDays, 'day')

  // Same year: "Mar 15"
  if (date.getFullYear() === now.getFullYear()) {
    return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  }

  // Older: "Mar 15, 2023"
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

// Uses Intl.RelativeTimeFormat for i18n-aware formatting
function formatRelative(value: number, unit: Intl.RelativeTimeFormatUnit): string {
  // Intl.RelativeTimeFormat uses negative values for past
  const rtf = new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' })
  return rtf.format(-value, unit)
}
```

```tsx
// RelativeTime.tsx — client component that updates live
'use client'

import { useEffect, useState } from 'react'
import { getRelativeTimeFormat } from '@/lib/relative-time'

interface RelativeTimeProps {
  date: Date | string
  // Absolute format for tooltip, aria-label, and <time> datetime attribute
  absoluteFormat?: Intl.DateTimeFormatOptions
  className?: string
}

export function RelativeTime({
  date,
  absoluteFormat = { dateStyle: 'long', timeStyle: 'short' },
  className,
}: RelativeTimeProps) {
  const dateObj = typeof date === 'string' ? new Date(date) : date

  // Server renders the absolute time — no hydration mismatch
  // Client immediately replaces with relative time on mount
  const [relative, setRelative] = useState<string>(
    dateObj.toLocaleDateString(undefined, absoluteFormat)
  )

  useEffect(() => {
    // Compute relative time immediately on mount
    function update() {
      setRelative(getRelativeTimeFormat(dateObj))
    }

    update()

    // Re-render every 30 seconds to keep "2 minutes ago" accurate
    // 30s is frequent enough for accuracy without being wasteful
    const interval = setInterval(update, 30_000)
    return () => clearInterval(interval)
  }, [dateObj])

  const absolute = dateObj.toLocaleString(undefined, absoluteFormat)

  return (
    <time
      dateTime={dateObj.toISOString()}  // Machine-readable ISO format for accessibility
      title={absolute}                   // Tooltip shows full timestamp on hover
      aria-label={absolute}             // Screen reader reads absolute time
      className={className}
    >
      {relative}
    </time>
  )
}
```

```tsx
// Usage
<RelativeTime date={post.createdAt} />
// Renders: "2 minutes ago" | "yesterday" | "Mar 15" | "Mar 15, 2023"

// In a feed where precise time matters
<RelativeTime
  date={comment.createdAt}
  absoluteFormat={{ dateStyle: 'medium', timeStyle: 'medium' }}
/>
```

```tsx
// SSR-safe version: render absolute on server, hydrate to relative on client
// Prevents "Text content did not match" hydration errors

// ❌ Wrong: server renders "2 minutes ago" which won't match client's "2 minutes ago" exactly
export function BadRelativeTime({ date }: { date: Date }) {
  return <time>{getRelativeTimeFormat(date)}</time>
}

// ✓ Correct: server renders absolute, client replaces with relative
// The initial useState value is the server-safe absolute string
export function GoodRelativeTime({ date }: { date: Date }) {
  const [display, setDisplay] = useState(date.toLocaleDateString()) // stable

  useEffect(() => {
    setDisplay(getRelativeTimeFormat(date))
    const id = setInterval(() => setDisplay(getRelativeTimeFormat(date)), 30_000)
    return () => clearInterval(id)
  }, [date])

  return <time dateTime={date.toISOString()}>{display}</time>
}
```

## Key Rules
- Always use `<time dateTime={isoString}>` — the ISO date in `datetime` serves accessibility, search engines, and browser extensions (calendar add, copy as date).
- Server-render the absolute time string in the initial state to avoid hydration mismatches.
- Replace with relative time in a `useEffect` on mount — this is a client-only enhancement.
- Use `setInterval` to refresh every 30 seconds — a frozen "2 minutes ago" after 40 minutes is confusing.
- Use `Intl.RelativeTimeFormat` for locale-aware output — never hardcode English strings like "ago".
- Use threshold-based format selection: seconds → minutes → hours → yesterday → days → month-day → full date.
- Show absolute time on hover via `title` and in `aria-label` — relative time without an absolute fallback is inaccessible.
- Never display times in UTC without conversion to the user's local timezone.
