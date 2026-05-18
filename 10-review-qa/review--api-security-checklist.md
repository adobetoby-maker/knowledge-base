# Review: API Security Checklist

## Authentication & Authorization

- [ ] Every route handler checks authentication before any data operation
  - Server Components: `supabase.auth.getUser()` (not `getSession()`)
  - Route Handlers: same pattern, return 401 if no user
  - Server Actions: same pattern, throw error if no user
- [ ] Authorization check: user can only access/modify their own data
  - `.eq('user_id', user.id)` on every query that returns user data
  - Admin role verified from database, not request headers
- [ ] Admin routes protected by role check from authenticated user's profile
- [ ] Cron/internal endpoints protected by `CRON_SECRET` header check
- [ ] Service role key (`SUPABASE_SERVICE_ROLE_KEY`) never used in client-side code
- [ ] No `NEXT_PUBLIC_` prefix on service role key or any secret

## Input Validation

- [ ] All request bodies validated with Zod before use
- [ ] Zod schema has min/max length bounds on string fields
- [ ] Number fields have min/max bounds (`z.number().min(1).max(1000000)`)
- [ ] File uploads validate MIME type and size before processing
- [ ] IDs from URL params validated as valid UUIDs: `z.string().uuid()`
- [ ] Array inputs have `.max()` length to prevent abuse
- [ ] `.strict()` used on Zod schemas for admin/sensitive endpoints (no extra fields)
- [ ] No `z.any()` on fields that affect data access or security

## Rate Limiting

- [ ] Login/auth endpoints rate limited (5 attempts per 15 minutes per IP)
- [ ] Password reset rate limited
- [ ] OTP/magic link endpoints rate limited
- [ ] Public data mutation endpoints rate limited
- [ ] Rate limit errors return 429 with `Retry-After` header

## Data Exposure

- [ ] Error messages don't reveal database schema, internal state, or stack traces
- [ ] API responses don't include fields not needed by the client
  - No raw database rows with all columns when only 3 fields are used
  - Specific `.select('id, name, email')` not `.select('*')`
- [ ] No sensitive fields (password_hash, secret_token, admin_notes) in list responses
- [ ] User IDs and internal IDs not exposed in URLs where not necessary

## CORS

- [ ] CORS configured to specific origins, not `*`
- [ ] `Access-Control-Allow-Credentials: true` only when combined with specific origin
- [ ] Preflight OPTIONS handlers return correct headers
- [ ] CORS not bypassed for "internal" routes accessed from browser

## Security Headers

- [ ] `Content-Security-Policy` set (via `next.config.ts` headers)
- [ ] `X-Frame-Options: DENY` or `SAMEORIGIN` (clickjacking protection)
- [ ] `X-Content-Type-Options: nosniff`
- [ ] HSTS header for production HTTPS

```ts
// next.config.ts — security headers
const securityHeaders = [
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' https://js.stripe.com",
      "img-src 'self' data: https:",
    ].join('; ')
  },
]
```

## Webhook Security

- [ ] Webhook endpoints verify provider signature (Stripe, GitHub, etc.)
- [ ] Webhook payloads processed idempotently (duplicate delivery safe)
- [ ] Webhook secret stored as env var, not hardcoded
- [ ] Raw request body used for signature verification (not parsed JSON)

```ts
// Stripe webhook signature verification
const sig = req.headers.get('stripe-signature')!
const rawBody = await req.text()
const event = stripe.webhooks.constructEvent(rawBody, sig, process.env.STRIPE_WEBHOOK_SECRET!)
```

## Secrets and Environment

- [ ] No secrets in source code (API keys, passwords, tokens)
- [ ] No secrets in git history — check with `git log -S "secret_value"`
- [ ] `.env.local` in `.gitignore`
- [ ] Production secrets different from development secrets
- [ ] Required env vars validated at startup with descriptive errors

## SQL Injection Prevention

- [ ] All database queries use parameterized queries (Supabase client handles this automatically)
- [ ] No string concatenation into SQL strings
- [ ] Raw SQL via `supabase.rpc()` or `$queryRaw` uses template literals (parameterized)
- [ ] User input never interpolated into SQL without parameterization

## Session Security

- [ ] Session cookies have `HttpOnly`, `Secure`, `SameSite=Lax` attributes
- [ ] JWT expiry set appropriately (not `exp: never`)
- [ ] Session invalidated on logout (server-side revocation if using custom JWTs)
- [ ] Auth tokens not stored in localStorage (use cookies for sensitive tokens)
