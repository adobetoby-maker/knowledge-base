# Disambig: Date and Time Handling

## The Question

Date/time is involved — which library, format, and storage strategy?

## Core Rules (Always)

1. **Store as UTC** in the database — always `timestamptz` (not `timestamp without time zone`)
2. **Display in user's timezone** — convert at render time, not at store time
3. **Transmit as ISO 8601** — `"2026-01-15T09:30:00Z"` in API responses
4. **Use `date-fns`** for formatting/arithmetic — not raw `Date` math

## Library Choice

**`date-fns`** — recommended for this stack:
- Tree-shakable (only imports functions used)
- Functional API (no mutation)
- Great TypeScript support

```ts
import { format, formatDistanceToNow, isToday, isPast, addDays, startOfMonth } from 'date-fns'

format(new Date(isoString), 'MMM d, yyyy')          // → "Jan 15, 2026"
format(new Date(isoString), 'MMMM d, yyyy h:mm a')  // → "January 15, 2026 9:30 AM"
formatDistanceToNow(new Date(createdAt), { addSuffix: true })  // → "3 hours ago"
isToday(new Date(dueDate))                           // → true/false
addDays(new Date(), 30)                              // → date 30 days from now
```

**`date-fns-tz`** — for timezone-aware formatting:
```ts
import { formatInTimeZone } from 'date-fns-tz'

// Show invoice date in client's timezone:
formatInTimeZone(new Date(invoice.created_at), userTimezone, 'MMM d, yyyy h:mm a')
```

## Storage Formats

| Type | DB Column Type | Example |
|------|---------------|---------|
| Timestamp with TZ | `timestamptz` | `2026-01-15 09:30:00+00` |
| Date only | `date` | `2026-01-15` |
| Duration | `integer` (seconds or minutes) | `3600` for 1 hour |
| Timezone | `text` | `'America/New_York'` (IANA name) |

**Never** store timezone-naive timestamps for anything that users across timezones interact with.

```sql
-- CORRECT: timestamps with timezone
created_at timestamptz DEFAULT now()
due_date date  -- Date only, no time component needed

-- WRONG: loses timezone context
created_at timestamp  -- What timezone?
```

## Zod Coercion for Dates

HTML inputs return strings. Use coercion in validation:

```ts
const schema = z.object({
  due_date: z.coerce.date()
    .min(new Date(), { message: 'Due date must be in the future' })
    .optional(),
})
```

`z.coerce.date()` accepts: Date objects, ISO strings, timestamps (numbers), numeric strings.

## Date Formatting Patterns

```ts
// Absolute dates (use when recency is important context):
format(date, 'MMM d, yyyy')      // "Jan 15, 2026"
format(date, 'MM/dd/yyyy')       // "01/15/2026" (US format)

// Relative dates (use for recent activity):
formatDistanceToNow(date, { addSuffix: true })  // "3 hours ago", "in 2 days"

// Conditional: relative for < 7 days, absolute for older
function formatInvoiceDate(dateStr: string): string {
  const date = new Date(dateStr)
  const daysDiff = Math.abs(differenceInDays(new Date(), date))
  return daysDiff < 7
    ? formatDistanceToNow(date, { addSuffix: true })
    : format(date, 'MMM d, yyyy')
}
```

## Timezone Display

```ts
// Get user's timezone from browser
const userTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone
// → "America/Boise"

// Store in user profile
await supabase.from('profiles').update({ timezone: userTimezone }).eq('id', userId)

// Display invoice time in user's timezone
import { formatInTimeZone } from 'date-fns-tz'
const displayTime = formatInTimeZone(invoice.created_at, profile.timezone, 'MMM d, h:mm a zzz')
```

## Due Date Logic

```ts
// Check if invoice is overdue
function isOverdue(invoice: Invoice): boolean {
  if (!invoice.due_date || invoice.status === 'paid') return false
  return isPast(new Date(invoice.due_date))
}

// Calculate due date based on payment terms
function calculateDueDate(issueDate: Date, paymentTermsDays: number): Date {
  return addDays(issueDate, paymentTermsDays)
}

// Format for display: show "Overdue" or "Due in X days"
function formatDueStatus(dueDateStr: string): string {
  const dueDate = new Date(dueDateStr)
  if (isToday(dueDate)) return 'Due today'
  if (isPast(dueDate)) return `Overdue by ${formatDistanceToNow(dueDate)}`
  return `Due ${formatDistanceToNow(dueDate, { addSuffix: true })}`
}
```

## SSR Hydration and Dates

Dates formatted with `new Date()` on the server differ from the client (different timezones). This causes hydration mismatch. Use `suppressHydrationWarning` on elements that display formatted dates, or format dates client-side only:

```tsx
function RelativeDate({ dateStr }: { dateStr: string }) {
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])

  if (!mounted) return <span className="text-muted-foreground">{format(new Date(dateStr), 'MMM d, yyyy')}</span>
  return <span>{formatDistanceToNow(new Date(dateStr), { addSuffix: true })}</span>
}
```
