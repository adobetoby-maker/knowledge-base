# Failure: Supabase Query Returns Empty Results (Data Exists)

**Symptom:** `supabase.from('posts').select()` returns `[]` or `null` but the data is clearly in the table.

**Cause (most common):** Row Level Security (RLS) policy is blocking access because there's no valid auth session.

## Diagnostic Checklist (in order)

```
1. Run the query directly in Supabase SQL Editor
   SELECT * FROM your_table LIMIT 5;
   → If results appear: RLS is blocking your code, not a data issue
   → If no results: data doesn't exist, wrong table name, or wrong project

2. Check if RLS is enabled
   SELECT relname, relrowsecurity FROM pg_class WHERE relname = 'your_table';
   → relrowsecurity = true means RLS is on

3. Check what policies exist
   SELECT * FROM pg_policies WHERE tablename = 'your_table';
   → Are there SELECT policies? If none: all reads are blocked when RLS is on

4. Check if there's an active session in your code
   const { data: { user } } = await supabase.auth.getUser()
   console.log(user) // null means no session → RLS rejects all queries
```

## The Fixes

### You're in a Server Component with no auth session
```typescript
// Problem: server.ts reads the cookie, but there's no user cookie
const supabase = createServerClient(...)
const { data } = await supabase.from('posts').select() // returns [] — RLS blocks unauthenticated

// Fix A: Use admin client (bypasses RLS) for data that doesn't need auth
import { supabaseAdmin } from '@/lib/supabase/admin'
const { data } = await supabaseAdmin.from('posts').select()

// Fix B: Add a public SELECT policy if the data is public
-- SQL: CREATE POLICY "public read" ON posts FOR SELECT USING (true);
```

### RLS policy exists but is too restrictive
```sql
-- Check the policy
SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = 'posts';

-- Common culprit: policy requires auth.uid() but no user is logged in
-- qual = (auth.uid() = user_id)

-- Fix: Add a policy for the specific access pattern you need
CREATE POLICY "users read own posts" ON posts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "public read published posts" ON posts
  FOR SELECT USING (status = 'published');
```

### Wrong Supabase client (server vs browser)
```typescript
// Problem: using browser client in a Server Component
import { createBrowserClient } from '@supabase/ssr'
// This doesn't have the server cookie context — no session → RLS blocks

// Fix: use server client
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
const supabase = createServerClient(url, key, { cookies })
```

### The `.single()` trap
```typescript
// Problem: .single() throws if 0 rows returned
const { data, error } = await supabase.from('users').select().eq('id', id).single()
// error.code = 'PGRST116' means "0 rows returned"

// Fix: check for this specific error vs real errors
if (error && error.code !== 'PGRST116') throw error
if (!data) return null // expected: user not found
```
