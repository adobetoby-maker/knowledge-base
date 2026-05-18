# Next.js Four-Cache Model

**When:** Understanding why data is stale, or configuring how long data stays fresh in a Next.js App Router app.
**Rule:** Next.js has 4 distinct caches. Knowing which one holds stale data determines how to fix it.

## The Four Caches

### 1. Request Memoization (per-request, in-memory)
**Scope:** Single server render pass
**Duration:** Current request only — never persists
**Purpose:** If two Server Components both `fetch('/api/user')`, the actual HTTP request is made once.
```typescript
// These two components in the same render tree call the same URL
// Next.js deduplicates them — only one actual HTTP request
const user = await fetch('/api/user')  // in ComponentA
const user = await fetch('/api/user')  // in ComponentB → returns cached value
```
**Control:** Automatic. Pass `{ cache: 'no-store' }` to opt a specific fetch out.

### 2. Data Cache (cross-request, persistent)
**Scope:** All requests, survives across deploys (stored on disk/CDN)
**Duration:** Until manually revalidated or TTL expires
**Purpose:** Store expensive computation results or API responses
```typescript
// Cached indefinitely (default for fetch in Server Components)
const data = await fetch('/api/expensive')

// Cached with TTL
const data = await fetch('/api/products', { next: { revalidate: 3600 } })

// Never cached
const data = await fetch('/api/live-price', { cache: 'no-store' })
```

### 3. Full Route Cache (HTML + RSC payload)
**Scope:** Static routes — pre-rendered at build time
**Duration:** Until next deployment or `revalidatePath()` called
**Purpose:** Serve static HTML without re-rendering on every request
```typescript
// Route is statically rendered (Full Route Cache active)
// No dynamic APIs used = Next.js pre-renders at build

// Opt out of full route cache (force dynamic rendering)
export const dynamic = 'force-dynamic'
export const revalidate = 60  // re-render every 60s (ISR)
```

### 4. Router Cache (client-side, in-memory)
**Scope:** User's browser session
**Duration:** 30s for dynamic pages, 5min for static pages
**Purpose:** Instant navigation — client stores visited route data
```typescript
// Force cache invalidation after mutation
import { useRouter } from 'next/navigation'
const router = useRouter()
router.refresh()  // invalidates Router Cache for current route
```

## Debugging Stale Data

### "My data isn't updating after I save to the DB"
```
1. Did you use revalidatePath() or revalidateTag() in the Server Action?
   → No → Add it after your DB mutation
2. Is the route statically rendered?
   → run ANALYZE=true npm run build, check if route is Static
3. Is the client still showing old data from Router Cache?
   → router.refresh() in the Client Component after mutation
```

### Force fresh data on a route
```typescript
// Route handler or Server Component
export const dynamic = 'force-dynamic'
// OR per-fetch:
const data = await fetch(url, { cache: 'no-store' })
```

### Revalidate after mutation
```typescript
// In a Server Action
'use server'
import { revalidatePath, revalidateTag } from 'next/cache'

async function updateUser(id: string, data: UserData) {
  await db.users.update({ where: { id }, data })
  revalidatePath('/users')       // invalidate specific path
  revalidateTag('users')         // invalidate all fetches tagged 'users'
}

// Tag a fetch to target it for revalidation
const users = await fetch('/api/users', { next: { tags: ['users'] } })
```
