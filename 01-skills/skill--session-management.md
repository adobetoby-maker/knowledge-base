# Skill: Session Management

## Overview

Sessions track authenticated state between requests. Options: cookie-based sessions (JWT or opaque token in cookie), Supabase Auth (managed sessions), or OAuth provider tokens. The key security invariant: validate the session on every authenticated request — never trust client-side state for authorization decisions.

## Cookie Session (jose + Supabase Auth Pattern)

```ts
// lib/session.ts
import { SignJWT, jwtVerify } from 'jose'

const SECRET = new TextEncoder().encode(process.env.SESSION_SECRET!)
const ALGORITHM = 'HS256'
const COOKIE_NAME = 'session'
const MAX_AGE = 7 * 24 * 60 * 60  // 7 days in seconds

interface SessionPayload {
  userId: string
  email: string
  role: 'user' | 'admin'
}

export async function createSession(payload: SessionPayload): Promise<string> {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: ALGORITHM })
    .setIssuedAt()
    .setExpirationTime(`${MAX_AGE}s`)
    .sign(SECRET)
}

export async function verifySession(token: string): Promise<SessionPayload | null> {
  try {
    const { payload } = await jwtVerify(token, SECRET)
    return payload as unknown as SessionPayload
  } catch {
    return null
  }
}
```

## Set Session Cookie

```ts
import { cookies } from 'next/headers'

export async function setSessionCookie(userId: string, email: string, role: 'user' | 'admin') {
  const token = await createSession({ userId, email, role })

  cookies().set(COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: MAX_AGE,
    path: '/',
  })
}

export async function clearSessionCookie() {
  cookies().delete(COOKIE_NAME)
}
```

## Read Session in Server Components

```ts
export async function getSession(): Promise<SessionPayload | null> {
  const cookieStore = cookies()
  const token = cookieStore.get(COOKIE_NAME)?.value
  if (!token) return null
  return verifySession(token)
}

// In a route handler or Server Component
export async function requireAuth(req?: Request): Promise<SessionPayload> {
  const session = await getSession()
  if (!session) {
    throw new Response(null, { status: 401 })
  }
  return session
}
```

## Middleware Session Check

```ts
// middleware.ts
import { NextRequest, NextResponse } from 'next/server'
import { verifySession } from '@/lib/session'

const PROTECTED_PATHS = ['/dashboard', '/admin', '/api/protected']

export async function middleware(req: NextRequest) {
  const isProtected = PROTECTED_PATHS.some(p => req.nextUrl.pathname.startsWith(p))
  if (!isProtected) return NextResponse.next()

  const token = req.cookies.get('session')?.value
  if (!token) {
    return NextResponse.redirect(new URL(`/login?redirect=${req.nextUrl.pathname}`, req.url))
  }

  const session = await verifySession(token)
  if (!session) {
    const res = NextResponse.redirect(new URL('/login', req.url))
    res.cookies.delete('session')  // Clear invalid cookie
    return res
  }

  // Inject user ID into headers for downstream use
  const requestHeaders = new Headers(req.headers)
  requestHeaders.set('x-user-id', session.userId)
  return NextResponse.next({ request: { headers: requestHeaders } })
}
```

## Session Rotation (Sliding Expiry)

Extend session on each request to keep active users logged in:

```ts
export async function rotateSession(res: NextResponse, session: SessionPayload) {
  const token = await createSession(session)
  res.cookies.set(COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: MAX_AGE,
    path: '/',
  })
}
```

## Server-Side Session Store (Opaque Tokens)

For sessions that need instant revocation (e.g., force-logout from admin):

```ts
// lib/session-store.ts (Redis/Upstash)
import { Redis } from '@upstash/redis'

const redis = Redis.fromEnv()

export async function createStoredSession(userId: string): Promise<string> {
  const sessionId = crypto.randomUUID()
  await redis.set(`session:${sessionId}`, JSON.stringify({ userId }), { ex: MAX_AGE })
  return sessionId
}

export async function getStoredSession(sessionId: string): Promise<{ userId: string } | null> {
  const data = await redis.get<string>(`session:${sessionId}`)
  return data ? JSON.parse(data) : null
}

export async function revokeSession(sessionId: string): Promise<void> {
  await redis.del(`session:${sessionId}`)
}

export async function revokeAllUserSessions(userId: string): Promise<void> {
  // Requires scanning — maintain a set per user
  const sessionIds = await redis.smembers(`user-sessions:${userId}`)
  if (sessionIds.length > 0) {
    await redis.del(...sessionIds.map(id => `session:${id}`))
    await redis.del(`user-sessions:${userId}`)
  }
}
```

## Key Rules

- `httpOnly: true` prevents JavaScript from reading the session cookie — protects against XSS token theft.
- `sameSite: 'lax'` protects against CSRF for most cases; `sameSite: 'strict'` breaks OAuth redirect flows.
- JWTs cannot be revoked — use a server-side session store (Redis) when you need force-logout or security-sensitive revocation.
- Validate session on the server on every protected request — don't cache session validity in client state.
- `getUser()` over `getSession()` in Supabase — `getSession()` trusts the client-provided JWT without re-validating with the server.
