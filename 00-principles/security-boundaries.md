# Security Boundaries — What Never Goes Where

**When:** Writing any code that handles credentials, keys, user data, or auth.
**Rule:** Know exactly where each secret is allowed to live. Violating these rules is not a bug — it's a breach.

## The Hard Rules

### Environment Variables
```
NEXT_PUBLIC_*    — visible to browser. Only use for non-secret public config.
Everything else  — server-only. Never access in client components.
```

Never put in code:
- Supabase service role key
- Stripe secret key
- Admin passwords
- Database URLs with credentials
- API keys with write access

### Supabase Keys
```
anon key (NEXT_PUBLIC_SUPABASE_ANON_KEY):
  ✅ Safe in browser — RLS protects the data
  ✅ Can be in NEXT_PUBLIC_ env var
  ❌ Don't use for admin operations (can't bypass RLS)

service role key (SUPABASE_SERVICE_ROLE_KEY):
  ✅ Server-only code: Route Handlers, Server Components, cron jobs
  ❌ Never in browser code
  ❌ Never in NEXT_PUBLIC_ env var
  ❌ Never in a client component
  ❌ Never in any file that might be bundled to the client
```

### Cookie Security
```typescript
// Admin session cookies must be:
cookies().set('admin_session', value, {
  httpOnly: true,    // not accessible via JavaScript
  secure: true,      // HTTPS only
  sameSite: 'strict', // no cross-site sends
  maxAge: 60 * 60 * 24 * 7  // 7 days
})
```

### Auth Checks
Never trust the client side alone for security decisions.
```typescript
// WRONG — client can modify localStorage
if (localStorage.getItem('isAdmin') === 'true') { ... }

// WRONG — client can modify the cookie value
const session = await supabase.auth.getSession() // reads client cookie

// RIGHT — validated server-side
const { data: { user } } = await supabase.auth.getUser() // validates with server
```

## What to Check Before Every Commit
```bash
# Scan for exposed secrets
grep -r "service_role\|eyJhbGciOi" --include="*.ts" --include="*.tsx" --include="*.env" . | grep -v ".gitignore\|node_modules"

# Check for hardcoded credentials
grep -r "password\|secret\|apikey\|api_key" --include="*.ts" --include="*.tsx" . | grep -v "process.env\|env.\|placeholder\|example\|test" | grep -v "node_modules"
```

## gitignore Must Contain
```
.env
.env.local
.env.production
.env*.local
*.pem
```

## The Admin Route Pattern
Every admin route must verify the session server-side before rendering:
```typescript
// app/admin/page.tsx
import { verifyAdmin } from '@/lib/adminAuth'
import { redirect } from 'next/navigation'

export default async function AdminPage() {
  const admin = await verifyAdmin()
  if (!admin) redirect('/admin/login')
  return <AdminDashboard />
}
```
