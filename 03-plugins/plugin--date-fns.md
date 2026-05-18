# Plugin: date-fns

## What It Is

`date-fns` is a modular date utility library. Tree-shakeable: only import the functions you use. Does not mutate dates. Works in any environment (browser, Node, Cloudflare Workers). Use `date-fns-tz` for timezone-aware operations.

## Installation

```bash
npm install date-fns date-fns-tz
```

## Core Functions Reference

| Function | Purpose | Example output |
|----------|---------|----------------|
| `format(date, pattern)` | Format date as string | `"Jan 15, 2026"` |
| `parseISO(str)` | Parse ISO string to Date | `new Date(...)` |
| `formatDistanceToNow(date)` | Relative time | `"3 hours ago"` |
| `isAfter(d1, d2)` | Comparison | `true/false` |
| `isBefore(d1, d2)` | Comparison | `true/false` |
| `differenceInDays(d1, d2)` | Days between | `7` |
| `addDays(date, n)` | Add days | `new Date(...)` |
| `subDays(date, n)` | Subtract days | `new Date(...)` |
| `startOfDay(date)` | Midnight | `Date at 00:00:00` |
| `endOfDay(date)` | End of day | `Date at 23:59:59` |
| `startOfMonth(date)` | First day | `Date at start` |
| `endOfMonth(date)` | Last day | `Date at end` |
| `isValid(date)` | Validate | `true/false` |

## Format Tokens

```ts
import { format } from 'date-fns'

const d = new Date('2026-01-15T14:30:00')

format(d, 'MMM d, yyyy')         // "Jan 15, 2026"
format(d, 'MMMM d, yyyy')        // "January 15, 2026"
format(d, 'MM/dd/yyyy')          // "01/15/2026"
format(d, 'h:mm a')              // "2:30 PM"
format(d, 'EEE, MMM d')          // "Thu, Jan 15"
format(d, "yyyy-MM-dd'T'HH:mm")  // "2026-01-15T14:30" (ISO without seconds)
```

Key tokens: `yyyy` = 4-digit year, `MM` = 2-digit month, `dd` = 2-digit day, `HH` = 24h hour, `hh` = 12h hour, `mm` = minutes, `a` = AM/PM.

## Parsing ISO Strings from Supabase

```ts
import { parseISO, format } from 'date-fns'

// Supabase returns timestamps as ISO strings
const invoice = { created_at: '2026-01-15T14:30:00Z' }

const date = parseISO(invoice.created_at)
const display = format(date, 'MMM d, yyyy')  // "Jan 15, 2026"
```

`parseISO` handles both `Z` (UTC) and `+00:00` suffixes. Don't use `new Date(str)` — browser parsing of non-UTC strings is implementation-dependent.

## Relative Time

```ts
import { formatDistanceToNow } from 'date-fns'

formatDistanceToNow(parseISO('2026-01-15T10:00:00Z'), { addSuffix: true })
// "2 hours ago" / "in 3 days"
```

Use for "last updated", "created at" — not for countdowns (use countdown timer pattern instead).

## Timezone-Aware Operations

```ts
import { format, toZonedTime, fromZonedTime } from 'date-fns-tz'

const userTz = 'America/Boise'  // Get from user preferences

// Display UTC timestamp in user timezone
const utcDate = parseISO('2026-01-15T19:00:00Z')
const zonedDate = toZonedTime(utcDate, userTz)
format(zonedDate, 'h:mm a', { timeZone: userTz })  // "12:00 PM"

// Store user's local time as UTC
const localDate = new Date('2026-01-15T12:00:00')
const utcToStore = fromZonedTime(localDate, userTz)
// Pass utcToStore.toISOString() to Supabase
```

Store timestamps as UTC in Postgres (`timestamptz`). Convert to user timezone only for display.

## Date Ranges for Queries

```ts
import { startOfMonth, endOfMonth, subMonths, format } from 'date-fns'

function getLastMonthRange() {
  const lastMonth = subMonths(new Date(), 1)
  return {
    from: format(startOfMonth(lastMonth), "yyyy-MM-dd'T'00:00:00'Z'"),
    to: format(endOfMonth(lastMonth), "yyyy-MM-dd'T'23:59:59'Z'"),
  }
}

// Use with Supabase
const { data } = await supabase
  .from('invoices')
  .select('*')
  .gte('created_at', range.from)
  .lte('created_at', range.to)
```

## Input Validation

```ts
import { isValid, parseISO } from 'date-fns'

function parseDate(input: string): Date | null {
  const parsed = parseISO(input)
  return isValid(parsed) ? parsed : null
}
```

Always validate before formatting — `format(new Date('invalid'), 'MMM d')` throws `RangeError`.

## Overdue Calculation

```ts
import { isBefore, startOfDay } from 'date-fns'

function isOverdue(dueDateISO: string): boolean {
  const due = startOfDay(parseISO(dueDateISO))
  const today = startOfDay(new Date())
  return isBefore(due, today)
}
```

## Zod Integration

```ts
import { z } from 'zod'

const dateSchema = z.string().refine(
  (s) => isValid(parseISO(s)),
  { message: 'Invalid date format' }
)

// Or coerce to Date
const dateSchema = z.coerce.date()  // Accepts ISO strings, Date objects, timestamps
```

## Locale Support

```ts
import { format } from 'date-fns'
import { ptBR } from 'date-fns/locale'

format(date, 'dd MMMM yyyy', { locale: ptBR })  // "15 janeiro 2026"
```

Import individual locales — don't import all locales (large bundle). Locale only affects display (month/day names), not parsing.
