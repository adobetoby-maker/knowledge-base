# Security By Default

## The Default Posture

Every new route is private until explicitly marked public. Every database table is locked until a policy grants access. Every user input is untrusted until validated.

Start locked — open only what's needed.

## Route Security Defaults

```typescript
// DEFAULT: require auth in every route handler
// Then explicitly allow public access where needed

// Admin route — cookie auth
export async function GET(req: NextRequest) {
  const isAdmin = await validateAdminSession(req)
  if (!isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  // ...
}

// Portal route — Supabase JWT
export default async function PortalPage() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')
  // ...
}

// Public route — explicitly documented as public
// No auth check — but no sensitive data returned
export async function GET() {
  const services = getPublicServices()  // only public data
  return NextResponse.json(services)
}
```

## Input Validation at Every Boundary

```typescript
// Zod schema for every Route Handler / Server Action input
import { z } from 'zod'

const CreateInvoiceSchema = z.object({
  customer_id: z.string().uuid(),
  line_items: z.array(z.object({
    description: z.string().min(1).max(500),
    quantity: z.number().positive().max(1000),
    unit_price: z.number().nonnegative().max(100000),
  })).min(1),
  notes: z.string().max(2000).optional(),
})

export async function POST(req: NextRequest) {
  const body = await req.json()
  const result = CreateInvoiceSchema.safeParse(body)
  
  if (!result.success) {
    return NextResponse.json({ error: result.error.issues }, { status: 400 })
  }
  
  const { customer_id, line_items, notes } = result.data
  // Use validated data — safe
}
```

## Environment Variable Security

```
NEXT_PUBLIC_* = safe to expose (client receives it)
Everything else = server only

SAFE to make NEXT_PUBLIC_:
  - SUPABASE_URL
  - SUPABASE_ANON_KEY  
  - STRIPE_PUBLISHABLE_KEY
  - SITE_URL

NEVER NEXT_PUBLIC_:
  - SUPABASE_SERVICE_ROLE_KEY  ← bypasses all RLS
  - STRIPE_SECRET_KEY
  - ADMIN_SECRET
  - ANTHROPIC_API_KEY
  - Any password, token, or private key
```

## Database Security Defaults

Every new table defaults to NO ACCESS via RLS:
```sql
-- Enable RLS on every new table
ALTER TABLE new_table ENABLE ROW LEVEL SECURITY;
-- Without this, anyone with the anon key can read/write all rows

-- Then explicitly grant what's needed
CREATE POLICY "..." ON new_table FOR SELECT
TO authenticated USING (...);
```

Never run `ALTER TABLE table DISABLE ROW LEVEL SECURITY` in production.

## CORS Security

Only allow specific origins — not `*` — for auth or sensitive endpoints:
```typescript
const allowedOrigins = [
  'https://jrsautorepair.worker-bee.app',
  process.env.NODE_ENV === 'development' ? 'http://localhost:3000' : '',
].filter(Boolean)

const origin = req.headers.get('origin')
if (origin && !allowedOrigins.includes(origin)) {
  return new Response('Forbidden', { status: 403 })
}
```

## SQL Injection Prevention

Supabase client uses parameterized queries automatically:
```typescript
// SAFE — parameterized
supabase.from('invoices').select('*').eq('id', userId)

// When using Supabase RPC:
supabase.rpc('get_invoice', { invoice_id: userId })
// Never concatenate user input into SQL strings
```

## Content Security Policy

Add CSP headers to prevent XSS:
```typescript
// next.config.ts
const securityHeaders = [
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline'",  // unsafe-inline needed for Next.js
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "connect-src 'self' https://*.supabase.co wss://*.supabase.co",
    ].join('; '),
  },
]
```

## OWASP Top 10 Checklist

| Risk | Mitigation |
|---|---|
| A1 Broken Access Control | Auth check on every protected route, RLS on every table |
| A2 Cryptographic Failures | HTTPS everywhere, signed cookies, AES-256-GCM for vault |
| A3 Injection | Supabase parameterized queries, Zod validation |
| A4 Insecure Design | Auth separated from data access, admin client server-only |
| A5 Security Misconfiguration | RLS on by default, no wildcards in CORS for auth endpoints |
| A6 Vulnerable Components | npm audit regularly, update dependencies |
| A7 Auth Failures | getUser() not getSession(), HTTP-only cookies, token expiry |
| A8 Software Integrity | Content-Security-Policy headers |
| A9 Logging Failures | Log auth failures, admin actions — never log passwords/tokens |
| A10 SSRF | Validate URLs before fetching, allowlist external domains |
