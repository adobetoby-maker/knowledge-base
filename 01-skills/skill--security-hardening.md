# Skill: security-hardening

**Trigger:** Implementing or reviewing security measures in web applications.
**Returns:** OWASP-aligned security patterns for Next.js + Supabase apps.

## Input Validation — Never Trust Client Input

All user input must be validated at the server boundary. TypeScript types are erased at runtime — they do not validate.

```typescript
// Wrong — TypeScript type is not runtime validation
async function createInvoice(data: { amount: number; description: string }) {
  await db.insert(data)  // amount could be -999999 at runtime
}

// Right — Zod validates at runtime
const schema = z.object({
  amount: z.number().positive().max(1000000),
  description: z.string().min(1).max(500).trim(),
})

const result = schema.safeParse(untrustedInput)
if (!result.success) return { error: 'Invalid input' }
```

## SQL Injection Prevention

Supabase's query builder is parameterized — safe by default. Never concatenate user input into SQL strings:

```typescript
// Safe — parameterized (always use this pattern)
const { data } = await supabase
  .from('users')
  .select('*')
  .eq('email', userInput)

// Safe — RPC with binding
const { data } = await supabase.rpc('get_user_by_email', { email: userInput })
```

## XSS Prevention

Next.js auto-escapes JSX expressions. When rendering HTML strings from user content, always sanitize first with DOMPurify before inserting. For SEO schema markup, use JSX children syntax rather than innerHTML injection patterns:
```typescript
<script type="application/ld+json">{JSON.stringify(schema)}</script>
```

For markdown user content, use ReactMarkdown which handles sanitization internally:
```typescript
import ReactMarkdown from 'react-markdown'
<ReactMarkdown>{userContent}</ReactMarkdown>
```

## Security Headers

```javascript
// next.config.js
const securityHeaders = [
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-XSS-Protection', value: '1; mode=block' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
]

module.exports = {
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }]
  }
}
```

## Secrets Management

```
NEVER put in code (even hardcoded in test files):
  - API keys
  - Database passwords
  - JWT secrets
  - OAuth client secrets

Store in:
  - .env.local (local dev, git-ignored)
  - Vercel environment variables (production)
  - Cloudflare secrets (wrangler secret put SECRET_NAME)

Prefix rule:
  - NEXT_PUBLIC_* = safe for browser (baked into JS bundle)
  - Everything else = server-only
```

## Rate Limiting — Prevent Abuse

Public endpoints that trigger expensive operations (AI, email, SMS) must be rate limited:

```typescript
// Using Upstash Redis with @upstash/ratelimit
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '1 m'),
})

const identifier = request.headers.get('x-forwarded-for') ?? 'anonymous'
const { success } = await ratelimit.limit(identifier)

if (!success) {
  return Response.json({ error: 'Too many requests' }, { status: 429 })
}
```

## Authentication Anti-Patterns

```
NEVER DO:
  - Store user role in a cookie or localStorage (can be tampered)
  - Trust client-supplied user ID (always read from verified session)
  - Use getSession() for security checks (use getUser() — server-verified)
  - Import admin.ts Supabase client in client components
  - Skip RLS because "the frontend already validates"

ALWAYS DO:
  - Verify auth on every Route Handler (no "already authenticated" assumption)
  - Check resource ownership: WHERE user_id = auth.uid()
  - Use service role only for legitimate cross-user admin operations
```

## CSRF Protection

Next.js App Router Route Handlers are automatically protected for same-origin requests via SameSite cookies. For additional protection on state-changing endpoints:

```typescript
export async function POST(request: Request) {
  const origin = request.headers.get('origin')
  if (origin !== process.env.NEXT_PUBLIC_URL) {
    return new Response('Forbidden', { status: 403 })
  }
}
```

## Dependency Security

```bash
npm audit                # check for known vulnerabilities
npm audit fix            # auto-fix safe updates
npm outdated             # view outdated packages
```

Run `npm audit` before every production deploy. Address CRITICAL and HIGH severity findings immediately.
