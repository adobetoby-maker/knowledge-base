# QA: Security Checklist

## Overview

Security review before shipping. Covers the most common vulnerabilities in web apps: injection attacks, auth bypasses, misconfigured access control, exposed credentials, and insecure data handling.

## Authentication

```
☐ All protected routes check authentication on the server (not just client-side)
☐ JWT tokens have expiry (expiresIn) set
☐ Session cookies are httpOnly, Secure, SameSite=Lax
☐ Passwords are hashed with bcrypt/argon2 (never MD5/SHA1)
☐ Password reset tokens expire (24h max) and are single-use
☐ Rate limiting on login endpoint (prevent brute force)
☐ No user enumeration via different error messages
```

```ts
// Unified auth error — don't reveal whether email exists
return Response.json({ error: 'Invalid email or password' }, { status: 401 })
// NOT: { error: 'Email not found' } or { error: 'Wrong password' }
```

## Authorization

```
☐ Every database query scoped to the authenticated user (no IDOR)
☐ Admin routes check admin role on the server
☐ RLS policies enabled on all Supabase tables
☐ Service role key never exposed to the client
☐ API routes verify the requesting user owns the resource
```

```ts
// BAD — IDOR: any authenticated user can access any order
const order = await db.query.orders.findFirst({ where: eq(orders.id, params.id) })

// GOOD — scoped to authenticated user
const order = await db.query.orders.findFirst({
  where: and(eq(orders.id, params.id), eq(orders.userId, session.userId))
})
if (!order) return new Response(null, { status: 404 })
```

## Injection

```
☐ All database queries use parameterized queries (no string interpolation)
☐ User input never passed to shell commands
☐ User input never used in file paths without sanitization
☐ JSON.parse errors are caught (malformed JSON causes uncaught exceptions)
```

```ts
// BAD — SQL injection
const result = await db.execute(`SELECT * FROM users WHERE email = '${email}'`)

// GOOD — parameterized
const result = await db.select().from(users).where(eq(users.email, email))
```

## XSS Prevention

```
☐ User content rendered through React element APIs (not raw DOM manipulation)
☐ JSON-LD schema built from server-controlled data only (no user input interpolated)
☐ If HTML passthrough is needed for trusted CMS content: use DOMPurify or rehype-sanitize
☐ CSP headers configured (Content-Security-Policy)
```

React's JSX rendering escapes output by default, preventing XSS. The risk arises only when bypassing this with raw string injection or DOM manipulation.

## Cross-Site Request Forgery (CSRF)

```
☐ State-modifying operations use POST/PUT/DELETE (not GET)
☐ Origin header checked for non-browser clients
☐ Next.js Server Actions have built-in CSRF protection
☐ Cookie SameSite=Lax prevents CSRF on most cross-site requests
```

## Sensitive Data Exposure

```
☐ No secrets in client-side code (no NEXT_PUBLIC_ prefix for secret keys)
☐ .env files in .gitignore
☐ API keys not logged
☐ Passwords not returned in API responses
☐ PII access logged for audit trail
```

```ts
// BAD — password hash exposed in API response
return Response.json(user)

// GOOD — omit sensitive fields
const { passwordHash, ...safeUser } = user
return Response.json(safeUser)
```

## File Upload

```
☐ File type validated on server (not just client or MIME header)
☐ File size limited server-side
☐ Uploaded files stored outside webroot
☐ Filenames sanitized (no path traversal)
```

```ts
function sanitizeFilename(filename: string): string {
  return path.basename(filename).replace(/[^a-zA-Z0-9._-]/g, '_')
}
```

## HTTP Security Headers

```ts
// next.config.ts
headers: async () => [
  {
    source: '/(.*)',
    headers: [
      { key: 'X-Frame-Options', value: 'DENY' },
      { key: 'X-Content-Type-Options', value: 'nosniff' },
      { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
      { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
    ],
  },
]
```

## Dependency Vulnerabilities

```bash
npm audit --audit-level=high
npm audit fix  # Non-breaking updates
```

## Key Rules

- IDOR is the most common authorization bug — every DB query on user-owned data must include `WHERE user_id = session.user_id`.
- Never reveal whether an email exists via different error messages — enables user enumeration for targeted attacks.
- `NEXT_PUBLIC_` env vars are embedded in client JS — never use for API keys, tokens, or secrets.
- Test authorization: log in as User A, try User B's resource IDs — should return 404 (not 403, to avoid leaking existence).
- Run `npm audit` before every release — known CVEs in dependencies are a common production incident source.
