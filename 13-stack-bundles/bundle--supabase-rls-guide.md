# Supabase RLS Complete Guide

## What RLS Is

Row Level Security is a PostgreSQL feature that adds security policies to tables. When enabled, a table only returns rows that pass the policy's `USING` condition. Supabase enables RLS by default on new tables.

Without RLS: every query returns all rows (dangerous for multi-tenant apps).
With RLS: each user only sees rows they're authorized to see.

## How Supabase Auth Integrates with RLS

When a user is authenticated via Supabase Auth, their JWT is passed in the `Authorization: Bearer` header. Supabase extracts the user's ID and makes it available as `auth.uid()` inside RLS policies.

```sql
-- auth.uid() = the logged-in user's UUID
-- auth.role() = 'authenticated' for logged-in users, 'anon' for anonymous

CREATE POLICY "Users can view own invoices"
ON invoices FOR SELECT
USING (auth.uid() = user_id);
```

## Policy USING vs WITH CHECK

- `USING` — controls which rows can be read and which can be modified (for UPDATE and DELETE)
- `WITH CHECK` — additional validation for INSERT and UPDATE (the new row must pass this check)

```sql
-- Read own rows
CREATE POLICY "View own invoices"
ON invoices FOR SELECT
USING (auth.uid() = user_id);

-- Write own rows + validate ownership on insert
CREATE POLICY "Insert own invoices"
ON invoices FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Modify own rows + prevent changing user_id
CREATE POLICY "Update own invoices"
ON invoices FOR UPDATE
USING (auth.uid() = user_id)      -- must own the row
WITH CHECK (auth.uid() = user_id); -- can't transfer to another user
```

## Standard Policy Set for a User-Owned Table

```sql
-- Enable RLS
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

-- Full CRUD for authenticated users on their own rows
CREATE POLICY "invoices_select_own"
ON invoices FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "invoices_insert_own"
ON invoices FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "invoices_update_own"
ON invoices FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "invoices_delete_own"
ON invoices FOR DELETE
USING (auth.uid() = user_id);
```

## Admin Access (Service Role)

The Supabase service role key bypasses ALL RLS policies. The admin Supabase client in this workspace (`lib/supabase/admin.ts`) uses the service role — it can read all rows regardless of RLS.

```typescript
// lib/supabase/admin.ts — bypasses RLS, server-only
import { createClient } from '@supabase/supabase-js'

export function createAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  )
}
```

Use the admin client ONLY in:
- Admin panel routes (`/admin/*`)
- Background jobs (cron, webhooks)
- Server-side operations that need to see all users' data

Never import in browser code or client components.

## Checking RLS Configuration

```sql
-- List all policies on a table
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'invoices';

-- Check if RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';

-- Tables without RLS (potential data exposure)
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
AND rowsecurity = false;
```

## Debugging RLS

When queries return empty and you can't tell if it's "no data" or "RLS blocked":

```typescript
// Test 1: Use admin client — bypasses RLS
const adminResult = await supabaseAdmin.from('invoices').select('*').eq('id', invoiceId)
// If this returns data, RLS is blocking the regular client

// Test 2: Check auth.uid() in context
const { data: { user } } = await supabase.auth.getUser()
console.log('User:', user?.id)  // null = not authenticated → RLS blocks everything

// Test 3: Check the policy conditions
// SELECT * FROM pg_policies WHERE tablename = 'invoices'
// Verify auth.uid() = user_id matches the actual column name
```

## Complex Policies

### Admin Role Policy

```sql
-- Users in an admins table can see everything
CREATE POLICY "Admins can view all invoices"
ON invoices FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM admins WHERE user_id = auth.uid()
  )
  OR
  auth.uid() = user_id  -- or own row
);
```

### Public Read, Auth Write

```sql
-- Anyone can view published articles
CREATE POLICY "Public can read published articles"
ON articles FOR SELECT
USING (published = true);

-- Only authenticated users (authors) can write
CREATE POLICY "Authors can insert own articles"
ON articles FOR INSERT
WITH CHECK (auth.uid() = author_id);
```

### Shared Resources

```sql
-- Users can view invoices they created OR are invited to
CREATE POLICY "Shared invoice access"
ON invoices FOR SELECT
USING (
  auth.uid() = user_id
  OR
  auth.uid() IN (
    SELECT user_id FROM invoice_shares WHERE invoice_id = invoices.id
  )
);
```
