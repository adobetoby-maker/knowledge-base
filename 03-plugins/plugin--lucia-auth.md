# Lucia Auth

Lucia is a session-based auth library that gives you complete control over the auth layer with no magic under the hood. It does not generate JWTs by default, does not abstract away your database, and does not provide any UI — you own everything.

## When Lucia Beats NextAuth

**Use Lucia when:**
- You want sessions stored in your own database, not opaque JWTs
- You need to invalidate all sessions for a user instantly (server-side revocation)
- You want to understand exactly what every line of auth code does
- You're on a non-Next.js framework or a custom server

**Use NextAuth when:**
- You need OAuth providers wired up in minutes with minimal custom code
- You're fine with JWT sessions and don't need immediate revocation

Lucia's value is transparency and control. If Lucia's session model doesn't match what you need, you'll know immediately — nothing is hidden.

## Core Concepts

Lucia manages two things: **users** and **sessions**. Sessions are rows in your database. A session has an ID (a random token), a userId, and an expiry time. The session ID is sent to the browser as a cookie and looked up on every request.

Lucia does not care what database you use. You pass it an adapter that implements `getSessionAndUser()`, `createSession()`, `updateSessionExpiration()`, and `deleteSession()`.

## Setup (Drizzle + PostgreSQL example)

```ts
// lib/auth.ts
import { Lucia } from 'lucia'
import { DrizzlePostgreSQLAdapter } from '@lucia-auth/adapter-drizzle'
import { db } from './db'
import { sessions, users } from './schema'

const adapter = new DrizzlePostgreSQLAdapter(db, sessions, users)

export const lucia = new Lucia(adapter, {
  sessionCookie: {
    attributes: {
      secure: process.env.NODE_ENV === 'production',
    },
  },
  getUserAttributes: (dbUser) => ({
    email: dbUser.email,
    role: dbUser.role,
  }),
})

declare module 'lucia' {
  interface Register {
    Lucia: typeof lucia
    DatabaseUserAttributes: { email: string; role: string }
  }
}
```

The `getUserAttributes` function controls what's attached to `session.user` — only expose what you actually need.

## Creating a Session

After verifying credentials (password check, OAuth callback, etc.):

```ts
import { lucia } from '@/lib/auth'
import { generateId } from 'lucia'

// Create user row first, then:
const session = await lucia.createSession(userId, {})
const sessionCookie = lucia.createSessionCookie(session.id)

// In Next.js Route Handler:
cookies().set(sessionCookie.name, sessionCookie.value, sessionCookie.attributes)
```

The session ID is a cryptographically random string Lucia generates. Never construct session IDs yourself.

## Validating a Session (Server)

```ts
import { lucia } from '@/lib/auth'
import { cookies } from 'next/headers'

export async function validateRequest() {
  const sessionId = cookies().get(lucia.sessionCookieName)?.value ?? null
  if (!sessionId) return { user: null, session: null }

  const { user, session } = await lucia.validateSession(sessionId)

  // Lucia auto-extends sessions nearing expiry — refresh the cookie
  if (session?.fresh) {
    const refreshed = lucia.createSessionCookie(session.id)
    cookies().set(refreshed.name, refreshed.value, refreshed.attributes)
  }
  if (!session) {
    const blank = lucia.createBlankSessionCookie()
    cookies().set(blank.name, blank.value, blank.attributes)
  }

  return { user, session }
}
```

Call this at the top of every Server Component or Route Handler that needs identity. It's a single DB read.

## Invalidating Sessions

```ts
// Sign out current session
await lucia.invalidateSession(sessionId)
cookies().set(lucia.createBlankSessionCookie().name, '', { maxAge: 0 })

// Invalidate ALL sessions for a user (password change, suspicious activity)
await lucia.invalidateUserSessions(userId)
```

This is the critical advantage over JWTs: revocation is instant and guaranteed. A JWT can't be revoked until it expires.

## Password Hashing

Lucia has no opinion on password hashing. Use `bcrypt` or `argon2`:

```ts
import { hash, verify } from '@node-rs/argon2'

const hashed = await hash(password, { memoryCost: 19456, timeCost: 2, outputLen: 32 })
const valid = await verify(hashed, inputPassword)
```

Argon2id is preferred over bcrypt for new projects.

## Session Table Schema (Drizzle)

```ts
export const sessions = pgTable('sessions', {
  id: text('id').primaryKey(),
  userId: text('user_id').notNull().references(() => users.id),
  expiresAt: timestamp('expires_at', { withTimezone: true, mode: 'date' }).notNull(),
})
```

Lucia's adapter expects exactly this shape. Add indexes on `userId` — session lookups join to users.

## Key Rules

- Always call `validateRequest()` server-side — never trust a client-sent userId
- Refresh the session cookie when `session.fresh` is true, or sessions silently expire
- Set a blank cookie when validation fails to clear stale cookies from browsers
- `invalidateUserSessions()` is the right response to password changes and account compromises
- Do not store sensitive data in session metadata — store it in the user row and expose via `getUserAttributes`
- Use argon2id over bcrypt for new password hashing implementations
- Index `sessions.user_id` — high-traffic apps will hit this join on every authenticated request
