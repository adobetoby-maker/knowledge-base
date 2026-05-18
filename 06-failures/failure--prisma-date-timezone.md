# Failure: Prisma DateTime Timezone Issues

## Overview
Prisma stores `DateTime` fields as UTC in the database and returns JavaScript `Date` objects. The silent failure: Node.js uses the server's system timezone (not UTC) when formatting dates with methods like `toLocaleString()`, `toLocaleDateString()`, or date libraries that read the local timezone. If the server's TZ is not UTC, dates shift by hours. The fix is always set `TZ=UTC` in production and serialize dates as ISO strings, never as locale strings.

## The Core Problem

```ts
// In Prisma schema
model Invoice {
  id         String   @id
  created_at DateTime @default(now())  // stored as UTC in DB
}

// What Prisma returns
const invoice = await prisma.invoice.findFirst()
console.log(invoice.created_at)  // Date object — correct UTC time internally

// The bug: display timezone depends on server TZ
console.log(invoice.created_at.toLocaleString())
// In UTC: "5/18/2025, 2:00:00 PM"
// In America/New_York (UTC-4): "5/18/2025, 10:00:00 AM"  ← WRONG
// In Asia/Tokyo (UTC+9): "5/18/2025, 11:00:00 PM"       ← WRONG
```

## Always Set `TZ=UTC` in Production

```bash
# In .env or deployment config
TZ=UTC

# Vercel — set in environment variables
# Railway — set TZ=UTC in env vars
# Heroku — heroku config:set TZ=UTC
# Docker
ENV TZ=UTC
```

```json
// package.json — for local dev consistency
{
  "scripts": {
    "dev": "TZ=UTC next dev",
    "test": "TZ=UTC vitest"
  }
}
```

## Serialize as ISO String for API Responses

```ts
// BAD — serialization may use server timezone
res.json({
  createdAt: invoice.created_at.toLocaleString(),  // timezone-dependent string
  dueDate: invoice.due_date.toLocaleDateString(),   // same problem
})

// GOOD — ISO string is always UTC, parseable anywhere
res.json({
  createdAt: invoice.created_at.toISOString(),  // "2025-05-18T14:00:00.000Z"
  dueDate: invoice.due_date.toISOString(),
})
```

ISO 8601 format (`toISOString()`) always includes the `Z` suffix indicating UTC. Frontend can then convert to user's local timezone with `Intl.DateTimeFormat`.

## Display in User's Timezone on the Frontend

```ts
// Client-side — always use browser timezone, not server timezone
function formatDate(isoString: string, userTimezone?: string) {
  return new Intl.DateTimeFormat('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: userTimezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone,
  }).format(new Date(isoString))
}

// Usage
formatDate('2025-05-18T14:00:00.000Z')
// Displays "May 18, 2025, 10:00 AM" in New York
// Displays "May 18, 2025, 11:00 PM" in Tokyo
// — correct! User sees their local time
```

## Prisma and Database Timezone Precision

```sql
-- PostgreSQL: TIMESTAMP WITH TIME ZONE vs TIMESTAMP WITHOUT TIME ZONE
-- Prisma @db.Timestamptz stores with timezone offset
-- Prisma DateTime maps to TIMESTAMP(3) — millisecond precision, no TZ stored
-- But Postgres normalizes to UTC regardless of input

-- When inserting with an explicit timezone:
INSERT INTO invoices (due_date) VALUES ('2025-05-18 14:00:00-04:00');
-- Postgres stores as: 2025-05-18 18:00:00 UTC
```

Prisma always reads back as UTC JavaScript Date. The timezone of the original insert is normalized away.

## Date Arithmetic Pitfalls

```ts
// BAD — adding days using local time (breaks at DST transitions)
const tomorrow = new Date()
tomorrow.setDate(tomorrow.getDate() + 1)  // DST: may add 23 or 25 hours

// GOOD — use a date library that handles DST
import { addDays } from 'date-fns'
import { addDays as addDaysUTC } from 'date-fns/utc'

const tomorrow = addDaysUTC(new Date(), 1)  // always exactly 24h

// Or with day.js
import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
dayjs.extend(utc)
const tomorrow = dayjs.utc().add(1, 'day').toDate()
```

## Key Rules
- Always set `TZ=UTC` in production environments — inconsistent server timezone is the root cause of most date bugs
- Use `toISOString()` for all date serialization in API responses — never `toLocaleString()` or `toString()`
- Display timezone conversion happens on the frontend in the user's browser, not on the server
- Store user's preferred timezone in their profile if you need consistent server-side formatting
- `new Date()` on the server = "now" in the server's timezone — add `TZ=UTC` or use `Date.now()` (always UTC millis)
- Date arithmetic: use `date-fns`, `dayjs/utc`, or `luxon` — not raw `setDate()`
