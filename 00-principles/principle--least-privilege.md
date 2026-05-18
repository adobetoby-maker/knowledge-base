# Principle: Least Privilege

## The Problem

Code that has more access than it needs creates blast radius when it's compromised or has bugs. A bug in a blog rendering function shouldn't be able to delete invoices. A public API route shouldn't have access to private credentials. Each unit of code should have only the permissions required for its job.

## Application Layers

**Client-side code**: ONLY gets public data. Never `SUPABASE_SERVICE_ROLE_KEY`, never `ANTHROPIC_API_KEY`, never admin credentials. Anything in `NEXT_PUBLIC_*` is visible to every visitor.

**Server Components / Route Handlers with user auth**: Gets data belonging to the authenticated user. RLS enforces this at the database level — even if code is buggy, a user can't read another user's data.

**Admin-only code**: Uses the service role client. Only in Route Handlers behind admin auth checks. Never imported in files that could run in the browser. Never in Server Components that don't first verify admin session.

**Cron jobs / background workers**: Get exactly the permissions needed for their specific task. A job that reads and updates `invoices` shouldn't also have access to `auth.users`.

## Supabase Client Selection

```ts
// lib/supabase/client.ts — browser, public data only
// lib/supabase/server.ts — respects RLS, user-scoped
// lib/supabase/admin.ts — bypasses ALL RLS — service role only
```

Rule: use the least-privileged client that works for the task.
- User's own data? → `server.ts` client
- Public data? → `server.ts` client or `client.ts`
- Admin operation? → `admin.ts` client, ONLY after verifying admin session

## RLS as Enforcement

RLS is not just a convenience — it's the enforcement layer for least privilege at the database:

```sql
-- Users can only read their own invoices
CREATE POLICY "users see own invoices"
ON invoices FOR SELECT
USING (user_id = auth.uid());

-- Even if Route Handler code has a bug and doesn't filter by user,
-- RLS ensures the query only returns the requesting user's rows
```

## Environment Variables

```
BAD:  NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY  — visible to all users
BAD:  NEXT_PUBLIC_ANTHROPIC_API_KEY          — reveals API key to browser

GOOD: SUPABASE_SERVICE_ROLE_KEY              — server-only
GOOD: ANTHROPIC_API_KEY                      — server-only
```

A leaked service role key allows full database access with no RLS enforcement. A leaked Anthropic key runs up your bill. Scope all sensitive credentials to server-only.

## Route Handler Auth Checks

```ts
// Principle: verify at the gate, not deep inside
export async function GET(request: NextRequest) {
  // Establish privilege level immediately
  const session = await validateAdminSession(request)
  if (!session) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // Only proceed if privilege check passed
  // ... rest of handler
}
```

Don't sprinkle auth checks throughout the function — verify once at entry and short-circuit immediately on failure.

## API Keys to Third-Party Services

Third-party API keys should have the minimum scopes needed:
- Resend API key: only "Sending access", not "Full access"
- Stripe key: restricted key with only the webhook events you handle
- Supabase service role: if a job only reads, consider a DB user with read-only permissions

When using platform-scoped API keys (Cloudflare, Vercel), prefer API tokens with specific resource access over account-level tokens.

## Dependency Principle

Libraries have access to everything imported into the same context. A malicious or compromised package that's imported client-side can exfiltrate browser storage. Dependencies installed as server-only packages have less blast radius than client bundles.

```ts
// Server-only marker — prevents import in client-side code
import 'server-only'
```

Add to `lib/supabase/admin.ts` and any module containing secrets.

## Minimal DB Columns in SELECT

```sql
-- BAD: selects everything including sensitive fields
SELECT * FROM users WHERE id = $1;

-- GOOD: select only what the feature needs
SELECT id, name, avatar_url FROM users WHERE id = $1;
```

In Supabase queries:
```ts
.select('id, name, avatar_url')  // not .select('*')
```

This reduces the data exposed if a query result is accidentally logged or sent to the wrong place.
