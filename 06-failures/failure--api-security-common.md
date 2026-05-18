# Failure: Common API Security Mistakes

## 1. Unauthenticated Endpoints Returning Sensitive Data

```ts
// WRONG — no auth check
export async function GET(req: Request) {
  const { data } = await supabase.from('users').select('*')
  return Response.json(data)
}

// CORRECT
export async function GET(req: Request) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return new Response('Unauthorized', { status: 401 })

  const { data } = await supabase.from('users').select('id, name')
    .eq('id', user.id)  // Only own data
  return Response.json(data)
}
```

## 2. Missing Authorization After Authentication

Authentication (who are you?) and authorization (are you allowed?) are different:

```ts
// WRONG — authenticated but not authorized
export async function DELETE(req: Request, { params }: { params: { id: string } }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return new Response('Unauthorized', { status: 401 })

  // Deletes ANY comment, not just the user's own
  await supabase.from('comments').delete().eq('id', params.id)
  return new Response(null, { status: 204 })
}

// CORRECT — delete only own comment
await supabase.from('comments').delete()
  .eq('id', params.id)
  .eq('user_id', user.id)  // Authorization check
```

## 3. Trusting User-Supplied IDs for Ownership

```ts
// WRONG — body.userId controls which profile is updated
export async function PUT(req: Request) {
  const body = await req.json()
  await supabase.from('profiles').update(body.data).eq('id', body.userId)
}

// CORRECT — always use authenticated user's ID
export async function PUT(req: Request) {
  const body = await req.json()
  const { data: { user } } = await supabase.auth.getUser()
  // userId comes from auth, never from request body
  await supabase.from('profiles').update(body.data).eq('id', user.id)
}
```

## 4. Leaking Data in Error Messages

```ts
// WRONG — error reveals database structure / internal state
if (error) return Response.json({ error: error.message })  // "duplicate key value violates unique constraint..."

// CORRECT — generic error for client, detailed log server-side
if (error) {
  console.error('DB error:', error)
  return Response.json({ error: 'Unable to complete request' }, { status: 500 })
}
```

## 5. Missing Rate Limiting on Auth Endpoints

Brute-force protection is mandatory on:
- Login: prevent password guessing
- Magic link: prevent spam
- Password reset: prevent email flooding
- OTP verification: prevent brute-forcing 6-digit codes

```ts
// app/api/auth/login/route.ts
import { rateLimit } from '@/lib/rateLimit'

export async function POST(req: Request) {
  const ip = req.headers.get('x-forwarded-for') ?? 'unknown'
  const { success } = await rateLimit.limit(`login:${ip}`, { limit: 5, window: '15m' })

  if (!success) {
    return Response.json({ error: 'Too many attempts. Try again in 15 minutes.' }, { status: 429 })
  }
  // ...
}
```

## 6. Not Validating Request Body Size

```ts
// WRONG — no body size limit
export async function POST(req: Request) {
  const body = await req.text()  // Could be gigabytes
}

// CORRECT — check Content-Length first
export async function POST(req: Request) {
  const contentLength = req.headers.get('content-length')
  if (contentLength && parseInt(contentLength) > 1_000_000) {  // 1MB limit
    return new Response('Payload too large', { status: 413 })
  }
  const body = await req.json()
}
```

Vercel enforces a 4.5MB limit on request bodies, but that's too large for most API payloads. Validate expected sizes explicitly.

## 7. CORS Misconfiguration

```ts
// WRONG — wildcard CORS on authenticated endpoints
headers.set('Access-Control-Allow-Origin', '*')
headers.set('Access-Control-Allow-Credentials', 'true')

// WRONG — '*' and 'true' credentials together is invalid and browsers reject it
// The combination was an attempt to allow credentials from any origin, but it doesn't work

// CORRECT — specific origin for authenticated endpoints
const origin = req.headers.get('origin')
const allowed = ['https://yourdomain.com', 'https://www.yourdomain.com']

if (origin && allowed.includes(origin)) {
  headers.set('Access-Control-Allow-Origin', origin)
  headers.set('Access-Control-Allow-Credentials', 'true')
}
```

## 8. Exposing Admin Routes Without Proper Protection

```ts
// WRONG — admin route with weak check
export async function DELETE(req: Request) {
  const isAdmin = req.headers.get('x-is-admin') === 'true'  // Client-controlled header!
  if (!isAdmin) return new Response('Forbidden', { status: 403 })
}

// CORRECT — verify admin role from authenticated user's data
export async function DELETE(req: Request) {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return new Response('Unauthorized', { status: 401 })

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()

  if (profile?.role !== 'admin') return new Response('Forbidden', { status: 403 })
}
```

## 9. Unprotected Cron/Internal Endpoints

```ts
// CORRECT — verify cron authentication
export async function GET(req: Request) {
  const authHeader = req.headers.get('Authorization')
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response('Unauthorized', { status: 401 })
  }
  // ...
}
```

Set `CRON_SECRET` as a long random value (`crypto.randomBytes(32).toString('hex')`). Vercel Cron and QStash both send this header automatically when configured correctly.
