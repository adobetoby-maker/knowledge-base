# Clerk Authentication

Clerk is a hosted auth platform providing UI components, SDKs, and a backend API for managing users, sessions, and organizations. Use it when you want enterprise-grade auth without building and maintaining it yourself.

## When to Use Clerk vs. Custom Auth

**Use Clerk when:**
- You need social login, MFA, passkeys, or magic links fast
- The project has organizations/teams with role-based access
- You want hosted sign-in UI you don't have to style or test
- Compliance or audit logging matters (Clerk stores logs)

**Roll your own (or use Lucia/NextAuth) when:**
- Auth data must live entirely in your own database
- You have non-standard session logic Clerk can't express
- Hosting cost at scale matters more than dev speed

## Setup

```bash
npm install @clerk/nextjs
```

Wrap the app root — this must be the outermost provider:

```tsx
// app/layout.tsx
import { ClerkProvider } from '@clerk/nextjs'

export default function RootLayout({ children }) {
  return (
    <ClerkProvider>
      <html><body>{children}</body></html>
    </ClerkProvider>
  )
}
```

## Middleware

`clerkMiddleware()` runs on every request and populates `auth()` for server components. Always configure a `publicRoutes` list — everything else is protected by default.

```ts
// middleware.ts
import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'

const isPublic = createRouteMatcher(['/', '/sign-in(.*)', '/sign-up(.*)'])

export default clerkMiddleware((auth, req) => {
  if (!isPublic(req)) auth().protect()
})

export const config = { matcher: ['/((?!_next|.*\\..*).*)'] }
```

Do not use `authMiddleware` — it is deprecated. Always use `clerkMiddleware`.

## Server Components

```ts
import { auth, currentUser } from '@clerk/nextjs/server'

// auth() gives you userId and sessionClaims cheaply — no extra request
const { userId, orgId, orgRole } = auth()
if (!userId) redirect('/sign-in')

// currentUser() fetches the full User object — costs a network call
const user = await currentUser()
```

Prefer `auth()` for guards; only call `currentUser()` when you need profile data.

## Client Hooks

```tsx
import { useUser, useAuth, useOrganization } from '@clerk/nextjs'

function Profile() {
  const { user, isLoaded } = useUser()         // full user object
  const { userId, signOut } = useAuth()         // lightweight auth state
  const { organization, membership } = useOrganization() // org context
  
  if (!isLoaded) return null
  return <p>{user.primaryEmailAddress.emailAddress}</p>
}
```

`useUser()` subscribes to real-time updates. `useAuth()` is cheaper when you only need `userId` or a token.

## Organizations and Roles

Clerk's org feature maps well to multi-tenant SaaS. Members have `org:admin` or `org:member` roles by default; you can add custom roles in the Clerk dashboard.

```ts
// Server: check org membership
const { orgRole } = auth()
if (orgRole !== 'org:admin') return new Response('Forbidden', { status: 403 })
```

Custom claims can inject org metadata into JWTs via Clerk's JWT Templates — useful when you need the role available in your own backend without a Clerk SDK call.

## Protecting API Routes

```ts
// app/api/data/route.ts
import { auth } from '@clerk/nextjs/server'

export async function GET() {
  const { userId } = auth()
  if (!userId) return new Response('Unauthorized', { status: 401 })
  // proceed
}
```

Never rely on client-sent userId. Always derive it from `auth()` server-side.

## Webhooks

Clerk emits `user.created`, `session.created`, etc. via webhooks. Use `svix` to verify the signature before syncing user data to your own database.

```ts
import { Webhook } from 'svix'
const wh = new Webhook(process.env.CLERK_WEBHOOK_SECRET)
const evt = wh.verify(body, headers) // throws on bad signature
```

## Key Rules

- Always wrap the app in `<ClerkProvider>` at the root — nested providers cause auth state gaps
- Use `clerkMiddleware()` not the deprecated `authMiddleware()`
- Prefer `auth()` over `currentUser()` — fewer network calls, same protection
- Derive `userId` server-side; never trust client-sent identity
- Sync users to your DB via webhook, not inline on first request
- Check `isLoaded` before rendering any auth-gated client UI to avoid flicker
- Use JWT Templates for passing org roles/custom claims to your own API
