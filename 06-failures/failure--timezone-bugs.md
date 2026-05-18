# Failure Pattern: Timezone Bugs

## Overview

Timezone bugs are among the hardest to reproduce — they appear at certain hours in certain regions, pass all tests (which run in developer's timezone), and cause silent data corruption. This guide covers the 5 most common patterns.

## Root Cause

Every JavaScript `Date` object is internally UTC. The timezone-local display is a rendering decision. Bugs happen when:
1. You mix up "when did this happen (UTC)" with "what the user typed (local time)"
2. You store `new Date()` thinking it's neutral when it's UTC milliseconds
3. You parse user input as UTC when they meant local time

## Bug 1: Parsing User-Entered Date as UTC

```ts
// User types "May 18 2026" in a form in San Francisco (UTC-7)
// They mean midnight San Francisco time

// Wrong
const date = new Date('2026-05-18')  // Parsed as UTC midnight
// → 2026-05-17T17:00:00.000Z  ← MAY 17 IN SF!
// User selected May 18. You stored May 17.

// Right — parse with explicit timezone using dayjs or date-fns-tz
import dayjs from 'dayjs'
import timezone from 'dayjs/plugin/timezone'
import utc from 'dayjs/plugin/utc'
dayjs.extend(utc)
dayjs.extend(timezone)

const userTimezone = 'America/Los_Angeles'
const date = dayjs.tz('2026-05-18', userTimezone).toDate()
// → 2026-05-18T07:00:00.000Z ✓
```

**Rule**: Never use `new Date('YYYY-MM-DD')` for user-entered local dates. Always parse with explicit timezone.

## Bug 2: Comparing Dates Across Timezones

```ts
// Is today's reservation overdue?

// Wrong
const today = new Date().toISOString().slice(0, 10)  // '2026-05-18' (UTC date!)
const dueDate = reservation.date  // '2026-05-18' (user's local date)
if (dueDate < today) ...  // Wrong if user is UTC-12 and it's still May 17 for them

// Right
const now = dayjs().tz(userTimezone)
const due = dayjs.tz(reservation.date, userTimezone)
const isOverdue = due.isBefore(now, 'day')
```

## Bug 3: Date Truncation in Database

```sql
-- User books appointment for "May 18 9:00 AM New York"
-- Stored as timestamptz in Postgres (correctly in UTC)

-- Wrong query: truncating to day in UTC
SELECT * FROM appointments
WHERE DATE_TRUNC('day', booked_at) = '2026-05-18';
-- Misses appointments from May 18 00:00-04:59 NY time (stored as May 17 UTC)

-- Right: truncate in user's timezone
SELECT * FROM appointments
WHERE DATE_TRUNC('day', booked_at AT TIME ZONE 'America/New_York') = '2026-05-18';
```

**Rule**: Any Postgres date truncation for display/filtering purposes should specify the timezone.

## Bug 4: DST (Daylight Saving Time) Edge Cases

```ts
// Adding 24 hours isn't always "tomorrow" during DST transitions

// Wrong — breaks on DST change day (2:00 AM → 1:00 AM)
const tomorrow = new Date(today.getTime() + 24 * 60 * 60 * 1000)

// Right — add days, not milliseconds
const tomorrow = dayjs().add(1, 'day').toDate()
// dayjs adds calendar days, not ms

// Also problematic: recurring events
// "Every day at 9:00 AM" needs to be stored as "09:00" (local time)
// NOT as UTC, because 9:00 AM UTC shifts by 1 hour on DST changes
```

## Bug 5: Displaying UTC Timestamps as Local Without Conversion

```tsx
// API returns: { createdAt: "2026-05-18T03:00:00.000Z" }

// Wrong — shows UTC time, confuses users in UTC-7 (shows 3:00 AM not 8:00 PM)
<time>{invoice.createdAt}</time>

// Right — convert to display timezone
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
dayjs.extend(relativeTime)

// Option A: relative (most user-friendly for recent events)
<time title={dayjs(invoice.createdAt).format('MMM D, YYYY h:mm A')}>
  {dayjs(invoice.createdAt).fromNow()}
</time>

// Option B: formatted local time (for older events)
<time>{dayjs(invoice.createdAt).format('MMM D, YYYY')}</time>
// Uses browser's local timezone automatically
```

## Rules for Timezone-Safe Code

1. **Store everything as UTC** in the database (`timestamptz` in Postgres, not `timestamp`)
2. **Convert to user timezone at display time**, never earlier
3. **Never parse bare date strings** (`'2026-05-18'`) without explicit timezone
4. **Use calendar-day math** (`add(1, 'day')`) not millisecond math for business logic
5. **Test with non-UTC timezones** — run `TZ=America/Los_Angeles npm test` in CI

## CI Timezone Testing

```bash
# Run tests in multiple timezones
TZ=UTC npm test
TZ=America/New_York npm test
TZ=America/Los_Angeles npm test
TZ=Asia/Tokyo npm test
TZ=Pacific/Auckland npm test  # UTC+13, catches day-rollover bugs
```

Auckland (UTC+13) is the best stress test — it's "tomorrow" when UTC is still today.
