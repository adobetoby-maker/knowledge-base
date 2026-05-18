# Failure: Session Expiry Issues

## Overview

Session expiry bugs cause users to be silently logged out mid-use, or conversely, to remain logged in forever when they shouldn't be. Common problems: JWTs that never expire, cookies with wrong maxAge, sessions not refreshed for active users, and no graceful handling when a token expires during an in-progress action.

## JWT Without Expiry

```ts
// BAD — no expiration
const token = jwt.sign({ userId: user.id }, SECRET)

// BAD — expiry too long (or secret key rotation never happens)
const token = jwt.sign({ userId: user.id }, SECRET, { expiresIn: '1y' })

// GOOD — short-lived access tokens, longer refresh tokens
const accessToken = jwt.sign({ userId: user.id }, SECRET, { expiresIn: '15m' })
const refreshToken = jwt.sign({ userId: user.id, type: 'refresh' }, REFRESH_SECRET, { expiresIn: '30d' })
```

## Cookie maxAge vs expires

```ts
// BAD — no maxAge means session cookie (deleted when browser closes)
res.setHeader('Set-Cookie', `session=${token}; HttpOnly; Secure; SameSite=Lax; Path=/`)

// BAD — maxAge = 0 immediately expires the cookie
cookies().set('session', token, { maxAge: 0 })

// GOOD — explicit expiry that matches the token's expiry
const MAX_AGE = 7 * 24 * 60 * 60  // 7 days in seconds

cookies().set('session', token, {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax',
  maxAge: MAX_AGE,
  path: '/',
})
```

## Not Refreshing Active Sessions (Sliding Expiry)

Users who are active should stay logged in. Without sliding expiry, they get logged out after a fixed window:

```ts
// middleware.ts — extend session on each request
export async function middleware(req: NextRequest) {
  const token = req.cookies.get('session')?.value
  if (!token) return NextResponse.next()

  const session = await verifySession(token)
  if (!session) return NextResponse.next()

  // Refresh if token expires in less than 1 hour
  const payload = decodeToken(token)
  const expiresIn = payload.exp * 1000 - Date.now()
  const ONE_HOUR = 60 * 60 * 1000

  const res = NextResponse.next()
  if (expiresIn < ONE_HOUR) {
    const newToken = await createSession(session)
    res.cookies.set('session', newToken, {
      httpOnly: true,
      secure: true,
      sameSite: 'lax',
      maxAge: MAX_AGE,
    })
  }

  return res
}
```

## Handling Expiry During In-Progress Actions

```tsx
// BAD — user gets a cryptic error mid-checkout when session expires
async function submitOrder(orderData: OrderData) {
  const res = await fetch('/api/orders', { method: 'POST', body: JSON.stringify(orderData) })
  if (!res.ok) throw new Error('Failed')  // Could be 401
}

// GOOD — detect 401 and redirect gracefully
async function apiRequest(url: string, options: RequestInit = {}) {
  const res = await fetch(url, options)

  if (res.status === 401) {
    // Save current action to redirect back after re-auth
    const returnTo = encodeURIComponent(window.location.href)
    window.location.href = `/login?redirect=${returnTo}&reason=session-expired`
    return  // Prevent further processing
  }

  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  return res.json()
}
```

## Supabase Token Refresh

Supabase handles token refresh automatically when using the SSR helpers, but only if called correctly:

```ts
// BAD — getSession() returns from local storage without re-validating
const { data: { session } } = await supabase.auth.getSession()

// GOOD — getUser() makes a server request to validate the JWT
const { data: { user }, error } = await supabase.auth.getUser()
if (error || !user) redirect('/login')
```

## Token Revocation Check

JWTs can't be revoked without a blocklist. For scenarios requiring instant revocation (password changed, account suspended):

```ts
async function verifySession(token: string): Promise<SessionPayload | null> {
  const payload = await verifyJwt(token)
  if (!payload) return null

  // Check revocation list (Redis)
  const isRevoked = await redis.sismember('revoked-sessions', payload.jti)
  if (isRevoked) return null

  return payload
}

async function revokeSession(jti: string, expiresAt: Date): Promise<void> {
  const ttl = Math.max(0, Math.floor((expiresAt.getTime() - Date.now()) / 1000))
  await redis.setex(`revoked:${jti}`, ttl, '1')
}
```

## Key Rules

- Always set `expiresIn` on JWTs — no expiry means tokens are valid forever even if stolen.
- `maxAge` (seconds) and `expires` (Date) both work for cookies — be consistent; don't mix them.
- Sliding expiry (refreshing the token on each request) keeps active users logged in.
- Detect 401 responses in the API client layer and redirect to login rather than showing a cryptic error.
- Supabase: `getUser()` validates server-side; `getSession()` trusts the client cookie — use `getUser()` for auth checks.
