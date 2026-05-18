# Failure: Timezone Display Bugs

## Overview
Servers run in UTC. Users live in their local timezone. When server-rendered timestamps are displayed as-is, a meeting at 2 PM UTC shows as "2:00 PM" to everyone — but a user in New York sees it and thinks "2 PM Eastern" (which is actually 6 PM UTC). This is a silent data corruption bug — the data is correct, but the display is wrong. The fix is to always render times in the user's local timezone on the client.

## The Core Problem

```
Server renders (UTC):  "Meeting at 14:00 UTC"
User in New York sees: "Meeting at 14:00"   ← thinks this means 14:00 Eastern (wrong!)
User in Tokyo sees:    "Meeting at 14:00"   ← thinks this means 14:00 JST (also wrong!)

Server sends ISO:      "2026-06-15T14:00:00Z"
User in New York sees: "10:00 AM EDT"       ← correct
User in Tokyo sees:    "11:00 PM JST"       ← correct
```

## Implementation

### Store and transmit as UTC ISO strings

```ts
// ALWAYS store timestamps in UTC in the database
// ALWAYS transmit as ISO 8601 with 'Z' suffix (UTC)
const event = {
  id: 'abc',
  title: 'Team meeting',
  startsAt: '2026-06-15T14:00:00.000Z',  // UTC — Z suffix is critical
}

// NEVER send localized strings from the server
// BAD:  "June 15 at 2:00 PM"  (which timezone?)
// GOOD: "2026-06-15T14:00:00.000Z"
```

### Client-side rendering with Intl.DateTimeFormat

```tsx
function EventTime({ isoUtc }: { isoUtc: string }) {
  const [localTime, setLocalTime] = useState<string>('')

  useEffect(() => {
    // Runs on client only — browser has access to user's timezone
    const date = new Date(isoUtc)
    const formatted = new Intl.DateTimeFormat('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      timeZoneName: 'short',
      // timeZone not specified = browser's local timezone
    }).format(date)
    setLocalTime(formatted)
  }, [isoUtc])

  if (!localTime) {
    // Render raw ISO during SSR/hydration — client updates it
    return (
      <time dateTime={isoUtc} suppressHydrationWarning>
        {new Date(isoUtc).toISOString()}
      </time>
    )
  }

  return <time dateTime={isoUtc}>{localTime}</time>
}
```

### Relative time ("3 hours ago") — same problem

```tsx
function RelativeTime({ isoUtc }: { isoUtc: string }) {
  const [relative, setRelative] = useState<string>('')

  useEffect(() => {
    const date = new Date(isoUtc)

    function update() {
      const diff = (Date.now() - date.getTime()) / 1000
      const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' })

      if (diff < 60)   setRelative(rtf.format(-Math.round(diff), 'second'))
      else if (diff < 3600) setRelative(rtf.format(-Math.round(diff / 60), 'minute'))
      else if (diff < 86400) setRelative(rtf.format(-Math.round(diff / 3600), 'hour'))
      else setRelative(rtf.format(-Math.round(diff / 86400), 'day'))
    }

    update()
    const interval = setInterval(update, 60000)  // Refresh every minute
    return () => clearInterval(interval)
  }, [isoUtc])

  return (
    <time dateTime={isoUtc} suppressHydrationWarning title={new Date(isoUtc).toLocaleString()}>
      {relative || '…'}
    </time>
  )
}
```

### User-specified timezone preference

```tsx
function useUserTimezone(): string {
  // Default to browser's timezone; allow user to override in their profile
  const { user } = useAuth()
  return user?.timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone
}

function formatInUserTimezone(isoUtc: string, timezone: string): string {
  return new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZoneName: 'short',
  }).format(new Date(isoUtc))
}
```

### suppressHydrationWarning explained

```tsx
// Server renders: "2026-06-15T14:00:00Z"
// Client renders: "Jun 15 at 10:00 AM EDT"
// This intentional mismatch would normally cause a React hydration error.
// suppressHydrationWarning tells React to accept the mismatch for this element.
// Use ONLY on leaf elements where the mismatch is intentional (time/date display).
<time dateTime={iso} suppressHydrationWarning>
  {formattedTime}
</time>
```

## Key Rules
- Store all timestamps in UTC — never store localized timestamps in the database
- Transmit ISO 8601 with UTC `Z` suffix — never transmit pre-formatted date strings
- Render all timestamps client-side in `useEffect` — server has no access to user's timezone
- `<time datetime="ISO">` preserves machine-readable UTC while displaying human-readable local time
- `suppressHydrationWarning` on `<time>` is the correct fix for intentional client/server mismatch
- Always display the timezone abbreviation (EDT, PST, JST) so users can verify the interpretation
- For scheduling features, let users set a timezone preference in their profile
- "3 days ago" has the same problem — the relative calculation depends on the current local time
