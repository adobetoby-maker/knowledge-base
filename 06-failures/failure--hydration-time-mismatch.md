# Failure: Date/Time Hydration Mismatch

## Overview
React hydration requires the server-rendered HTML to exactly match what the client would render on first pass. Relative timestamps like "3 days ago" or "2 hours from now" are computed from `Date.now()`, which differs between the server render time and the client hydration time — even by milliseconds, this produces a mismatch error. Absolute timestamps formatted with the user's local timezone are also mismatched because the server doesn't know the user's timezone.

## The Specific Error

```
Error: Hydration failed because the initial UI does not match what was rendered on the server.
Warning: Text content did not match. Server: "3 days ago" Client: "2 days ago"
Warning: Text content did not match. Server: "June 15, 2:00 PM" Client: "June 15, 4:00 PM PDT"
```

## Root Cause

```tsx
// This component will produce hydration mismatch:
function PostCard({ post }: { post: Post }) {
  return (
    <div>
      <h2>{post.title}</h2>
      <span>{formatRelativeTime(post.createdAt)}</span>  {/* Server: "3 days ago", Client: "2 days ago" */}
    </div>
  )
}

// Also problematic — timezone-dependent
function EventTime({ iso }: { iso: string }) {
  return <span>{new Date(iso).toLocaleString()}</span>  {/* Different on server vs client */}
}
```

## Fix 1: Render ISO on server, hydrate to human string on client

```tsx
function RelativeTime({ isoUtc }: { isoUtc: string }) {
  const [relative, setRelative] = useState<string | null>(null)

  useEffect(() => {
    // useEffect only runs on client — sets the human-readable string after hydration
    function compute() {
      const diff = (Date.now() - new Date(isoUtc).getTime()) / 1000
      const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' })

      if (diff < 60)    return rtf.format(-Math.round(diff), 'second')
      if (diff < 3600)  return rtf.format(-Math.round(diff / 60), 'minute')
      if (diff < 86400) return rtf.format(-Math.round(diff / 3600), 'hour')
      return rtf.format(-Math.round(diff / 86400), 'day')
    }

    setRelative(compute())
    const interval = setInterval(() => setRelative(compute()), 60000)
    return () => clearInterval(interval)
  }, [isoUtc])

  return (
    // suppressHydrationWarning on the <time> element:
    // - Server renders the ISO string (state is null on server)
    // - Client renders the relative string (state set in useEffect)
    // - React is told to accept this specific mismatch
    <time dateTime={isoUtc} suppressHydrationWarning>
      {relative ?? new Date(isoUtc).toLocaleDateString()}
    </time>
  )
}
```

## Fix 2: suppressHydrationWarning for intentional mismatches

```tsx
// suppressHydrationWarning tells React "I know these won't match, that's OK"
// Use it only on leaf elements where time/locale formatting causes the mismatch
// Don't use it to suppress real bugs — only for intentional client/server differences

function LocalTime({ isoUtc }: { isoUtc: string }) {
  return (
    <time
      dateTime={isoUtc}
      suppressHydrationWarning  // Accepts locale format difference between server and client
    >
      {new Date(isoUtc).toLocaleString()}
    </time>
  )
}
```

## Fix 3: next/dynamic with ssr: false for entire time-display components

```tsx
// If a component is purely about displaying times, exclude it from SSR entirely
import dynamic from 'next/dynamic'

const RelativeTimeDisplay = dynamic(() => import('./RelativeTime'), {
  ssr: false,
  loading: () => <span className="text-gray-400">…</span>,
})
```

## Fix 4: Stable server/client rendering with static date strings

```tsx
// Avoid mismatch entirely by rendering the same thing on server and client
// and upgrading to relative time after hydration

function PostMeta({ post }: { post: Post }) {
  const [isClient, setIsClient] = useState(false)

  useEffect(() => { setIsClient(true) }, [])

  const staticDate = new Date(post.createdAt).toLocaleDateString('en-US', {
    year: 'numeric', month: 'long', day: 'numeric',
  })

  return (
    <time dateTime={post.createdAt} suppressHydrationWarning>
      {isClient
        ? formatRelativeTime(post.createdAt)  // Client: "3 days ago"
        : staticDate                          // Server: "May 12, 2026"
      }
    </time>
  )
}
```

## Fix 5: Avoid Date.now() in component bodies during SSR

```tsx
// BAD: called during render (including server render)
function CountdownTimer({ expiresAt }: { expiresAt: string }) {
  const msLeft = new Date(expiresAt).getTime() - Date.now()  // Server and client differ
  return <span>{formatMs(msLeft)}</span>
}

// GOOD: computed only in useEffect (client-only)
function CountdownTimer({ expiresAt }: { expiresAt: string }) {
  const [msLeft, setMsLeft] = useState<number | null>(null)

  useEffect(() => {
    function update() {
      setMsLeft(new Date(expiresAt).getTime() - Date.now())
    }
    update()
    const interval = setInterval(update, 1000)
    return () => clearInterval(interval)
  }, [expiresAt])

  return (
    <time dateTime={expiresAt} suppressHydrationWarning>
      {msLeft !== null ? formatMs(msLeft) : '…'}
    </time>
  )
}
```

## Key Rules
- Never call `Date.now()` or `new Date()` directly in component render/return — use `useEffect` instead
- `<time datetime="ISO">` is the semantic element for times — use it with `suppressHydrationWarning`
- `suppressHydrationWarning` is acceptable only for time/locale formatting mismatches — not for actual bugs
- `useEffect` + `useState` is the correct pattern for any client-only computation
- "3 days ago" style display must be computed client-side — server time is not the user's current time
- For countdown timers, initialize to `null` server-side, compute in `useEffect`
- `next/dynamic({ ssr: false })` is the nuclear option for components that are fundamentally client-only
