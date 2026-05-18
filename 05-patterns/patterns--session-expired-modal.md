# Pattern: Session Expired Modal

## What This Solves

When a user's auth session expires mid-session, a 401 response from an API call needs to surface as an actionable dialog rather than a broken page. Hard-redirecting to `/login` destroys context — the user loses their place, any draft content, and the mental state of what they were doing. A modal overlay lets them re-authenticate without abandoning their current view.

## Detecting 401 Responses

The cleanest place to intercept 401s is at the fetch layer, not in individual components. A global fetch wrapper or TanStack Query's `onError` fires for every failed request.

```tsx
// lib/api-client.ts
export async function apiFetch(url: string, init?: RequestInit) {
  const res = await fetch(url, init)

  if (res.status === 401) {
    // Signal the session-expired state globally
    sessionExpiredBus.emit()
    // Throw so the calling code's error state activates
    throw new SessionExpiredError('Session expired')
  }

  if (!res.ok) throw new ApiError(res.status, await res.text())
  return res.json()
}

export class SessionExpiredError extends Error {}
```

Using a simple event bus (or Zustand store) decouples detection from UI:

```ts
// lib/session-bus.ts
import { create } from 'zustand'

interface SessionStore {
  isExpired: boolean
  setExpired: () => void
  reset: () => void
}

export const useSessionStore = create<SessionStore>((set) => ({
  isExpired: false,
  setExpired: () => set({ isExpired: true }),
  reset: () => set({ isExpired: false }),
}))
```

## The Modal Component

Mount the modal at the root layout so it's always available regardless of route:

```tsx
// components/SessionExpiredModal.tsx
'use client'
import { useSessionStore } from '@/lib/session-bus'

export function SessionExpiredModal() {
  const { isExpired, reset } = useSessionStore()
  const pathname = usePathname()
  const searchParams = useSearchParams()

  if (!isExpired) return null

  // Preserve current URL for post-login redirect
  const returnTo = encodeURIComponent(`${pathname}?${searchParams}`)

  return (
    <div className="fixed inset-0 z-[100] bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="session-expired-title"
        className="bg-background rounded-xl shadow-xl max-w-sm w-full p-6 space-y-4"
      >
        <h2 id="session-expired-title" className="text-lg font-semibold">
          Session expired
        </h2>
        <p className="text-sm text-muted-foreground">
          You've been signed out due to inactivity. Sign in again to continue
          where you left off.
        </p>
        <div className="flex flex-col gap-2">
          <a
            href={`/login?returnTo=${returnTo}`}
            className="w-full text-center px-4 py-2 bg-primary text-primary-foreground rounded-md text-sm font-medium"
            onClick={reset}
          >
            Sign in again
          </a>
          <a
            href="/login"
            className="w-full text-center px-4 py-2 border rounded-md text-sm text-muted-foreground"
            onClick={reset}
          >
            Go to login page
          </a>
        </div>
      </div>
    </div>
  )
}
```

## "Sign in again" vs "Go to login page"

These serve different mental models:

- **Sign in again** (`href="/login?returnTo=..."`) — user expects to come right back. Include the current URL as `returnTo`. After login, the server reads `returnTo` and redirects there. Use this as the primary CTA.
- **Go to login page** (`href="/login"`) — user wants to start fresh, maybe switch accounts. No `returnTo`. This is the escape hatch for users who want a clean state.

Never auto-redirect. The modal appearing on top of current content is intentional — it communicates that their work is still there and recoverable.

## Preserving Current URL

Encode the full `pathname + searchParams` before embedding in the link:

```ts
const current = `${pathname}${searchParams.toString() ? `?${searchParams}` : ''}`
const returnTo = encodeURIComponent(current)
// /login?returnTo=%2Fdashboard%2Finvoices%3Ffilter%3Dunpaid
```

In the login route handler, redirect after successful auth:

```ts
const returnTo = searchParams.get('returnTo')
const redirectTo = returnTo ? decodeURIComponent(returnTo) : '/dashboard'
// Validate returnTo is a relative path before using it
if (returnTo && !returnTo.startsWith('/')) redirect('/dashboard')
redirect(redirectTo)
```

Always validate that `returnTo` is a relative path — never redirect to an external URL from a query param.

## Preventing Duplicate Triggers

Multiple concurrent 401s will all fire `setExpired()`. The Zustand store's boolean is idempotent — setting it true multiple times is fine. The modal renders once.

## Key Rules

- Detect 401 at the fetch layer, not inside individual components or query error handlers
- Show a modal overlay, not a redirect — the user's current page content stays visible behind it
- "Sign in again" includes `returnTo`, "Go to login page" does not
- Always validate `returnTo` is a relative path before redirecting post-login
- The modal must have `role="dialog"` and `aria-modal="true"` for screen reader announcements
- Set `z-index` high enough (100+) to clear drawers, tooltips, and toasts
