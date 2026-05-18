# Date and Time Handling

## The Core Problems

1. **Timezone mismatch**: server and client may be in different timezones
2. **Hydration errors**: server renders a date string, client renders a different one → React hydration mismatch
3. **Float imprecision**: don't use floats for time calculations — use integer milliseconds or date libraries

## Storage: Always UTC in Database

```sql
-- ALWAYS store timestamps as TIMESTAMPTZ (UTC)
created_at TIMESTAMPTZ DEFAULT now()
due_date DATE  -- date-only: no timezone issue

-- NEVER store local time without timezone
-- BAD: created_at TIMESTAMP  (no timezone info)
```

## Displaying Dates in Next.js

**Problem**: Server renders date in UTC, client renders in local timezone → hydration mismatch.

**Solution**: Either render dates only client-side, or use UTC for both:

```typescript
// Option 1: Render date only on client (safe, no hydration issue)
'use client'
import { useEffect, useState } from 'react'

export function LocalDate({ isoString }: { isoString: string }) {
  const [formatted, setFormatted] = useState<string | null>(null)
  
  useEffect(() => {
    // Only runs in browser, where timezone is known
    setFormatted(new Date(isoString).toLocaleDateString())
  }, [isoString])
  
  if (!formatted) return <span suppressHydrationWarning>{isoString}</span>
  return <span>{formatted}</span>
}
```

```typescript
// Option 2: Format on server using UTC (consistent server/client)
function formatDateUTC(isoString: string): string {
  return new Date(isoString).toLocaleDateString('en-US', {
    timeZone: 'UTC',  // force UTC on both server and client
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
}
```

## Intl.DateTimeFormat vs date-fns

Prefer `Intl.DateTimeFormat` / `Date.toLocaleDateString()` for display — built-in, no bundle cost.

Use `date-fns` when:
- Complex relative times ("3 days ago")
- Date arithmetic (add/subtract days)
- Parsing non-ISO formats

```bash
npm install date-fns  # if needed — check if already in package.json first
```

```typescript
// date-fns examples
import { formatDistanceToNow, addDays, isAfter } from 'date-fns'

const ago = formatDistanceToNow(new Date(createdAt), { addSuffix: true })
// "3 days ago"

const nextWeek = addDays(new Date(), 7)
const isOverdue = isAfter(new Date(), new Date(dueDate))
```

## Invoice Due Dates

Due dates for invoices are `DATE` type (no time component). Display without timezone conversion:

```typescript
function formatDueDate(dateString: string): string {
  // dateString is 'YYYY-MM-DD' from Supabase DATE column
  // Parse as UTC to avoid off-by-one from timezone conversion
  const [year, month, day] = dateString.split('-').map(Number)
  return new Date(year, month - 1, day).toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric', 
    year: 'numeric',
  })
}
// "May 31, 2026" — no timezone conversion issues
```

## Checking Overdue

```typescript
// Compare dates without time to avoid timezone edge cases
function isOverdue(dueDateString: string): boolean {
  const today = new Date()
  today.setHours(0, 0, 0, 0)  // start of today, local time
  
  const [year, month, day] = dueDateString.split('-').map(Number)
  const dueDate = new Date(year, month - 1, day)  // local midnight
  
  return dueDate < today
}
```

## Formatting for Display

```typescript
// Common patterns using built-in Intl
const formatDate = (isoString: string) =>
  new Date(isoString).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
// "May 18, 2026"

const formatDateTime = (isoString: string) =>
  new Date(isoString).toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
// "May 18, 10:30 AM"

const formatRelative = (isoString: string) => {
  const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' })
  const diff = (new Date(isoString).getTime() - Date.now()) / 1000 / 60 / 60 / 24
  return rtf.format(Math.round(diff), 'day')
}
// "yesterday", "2 days ago", "in 3 days"
```

## Input Format for Supabase

When inserting timestamps:
```typescript
// ISO 8601 format — Supabase accepts this for TIMESTAMPTZ
const now = new Date().toISOString()
// "2026-05-18T10:30:00.000Z"

// For DATE columns:
const today = new Date().toISOString().split('T')[0]
// "2026-05-18"
```
