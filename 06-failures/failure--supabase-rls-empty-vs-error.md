# Supabase RLS: Empty Results vs Errors

## The Core Confusion

When a Supabase query returns `{ data: [], error: null }` with an empty array, there are two possible explanations:

1. **No rows exist** that match the query
2. **RLS blocked access** — rows exist but the policy denied them

Supabase returns an empty array in BOTH cases. It does NOT return a 403 or an RLS error message for SELECT queries (by design — revealing that rows exist but are denied is itself an information leak).

## Symptoms

```typescript
// This code looks correct but may be wrong
const { data: invoice, error } = await supabase
  .from('invoices')
  .select('*')
  .eq('id', invoiceId)
  .single()

// Returns: { data: null, error: { code: 'PGRST116', message: 'JSON object requested, rows returned is 0' } }
// This could mean: invoice doesn't exist OR RLS blocked it
// You cannot tell the difference
```

## Diagnosis Steps

When you get unexpected empty results:

**Step 1: Test with admin client**
```typescript
// If admin client returns data but regular client doesn't → RLS is blocking
import { createAdminClient } from '@/lib/supabase/admin'

const supabaseAdmin = createAdminClient()
const { data: adminResult } = await supabaseAdmin
  .from('invoices')
  .select('*')
  .eq('id', invoiceId)

console.log('Admin result:', adminResult)  // If this has data, RLS is the issue
```

**Step 2: Check RLS policies in Supabase dashboard**
```sql
-- List all policies on a table
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'invoices';
```

**Step 3: Check the user's auth status**
```typescript
const { data: { user } } = await supabase.auth.getUser()
console.log('Current user:', user?.id)  // null = not authenticated
// If user is null, ALL RLS policies that check auth.uid() will block
```

## Common RLS Policy Mistakes

### Missing auth check
```sql
-- BAD — this policy is basically "everyone can read everything"
CREATE POLICY "Users can view invoices"
ON invoices FOR SELECT
USING (true);  -- should be: auth.uid() = user_id

-- GOOD
CREATE POLICY "Users can view their invoices"
ON invoices FOR SELECT
USING (auth.uid() = user_id);
```

### Wrong column reference
```sql
-- BAD — references non-existent column
CREATE POLICY "Portal access"
ON invoices FOR SELECT
USING (auth.uid() = customer_id);  -- column is 'user_id', not 'customer_id'
```

### Forgetting service role bypasses RLS
```typescript
// Service role client (admin.ts) BYPASSES all RLS — good for server-side ops
// Regular client respects RLS — correct for user-facing operations

// If you accidentally use admin client in a user-facing route:
// Users see ALL rows, not just their own — data leak
```

### Session not established before query
```typescript
// WRONG — querying before auth is set up
const supabase = createClient()
const user = req.headers.get('x-user-id')  // custom header, not Supabase auth
const { data } = await supabase.from('invoices').select('*')
// auth.uid() returns null — RLS blocks everything

// CORRECT — use Supabase auth
const { data: { user } } = await supabase.auth.getUser()
if (!user) return 401
const { data } = await supabase.from('invoices').select('*').eq('user_id', user.id)
// auth.uid() returns the user's ID — RLS allows their rows
```

## For Portal Routes (jrs-auto-repair, silver-creek-logistics)

Portal users are authenticated via Supabase JWT. Their session is in the cookie. The server Supabase client reads that cookie to establish auth context.

```typescript
// lib/supabase/server.ts — reads session from cookie
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createClient() {
  const cookieStore = await cookies()
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll(), ... } }
  )
}
```

If the cookie is missing or expired, `auth.getUser()` returns null, and RLS blocks everything → empty results.

## Summary

Empty result = either no data OR RLS blocked. Always test with admin client when debugging unexpectedly empty queries.
