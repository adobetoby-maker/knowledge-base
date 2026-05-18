# Failure Patterns: Supabase RLS Gotchas

## RLS Enabled but No Policy = No Access

When you enable RLS on a table with no policies, ALL queries return empty (even for authenticated users):

```sql
-- This creates a table with RLS enabled but no access:
CREATE TABLE customers (id uuid PRIMARY KEY);
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
-- No CREATE POLICY → no one can read or write

-- Fix: always add policies when enabling RLS:
CREATE POLICY "Users can view customers"
ON customers FOR SELECT
TO authenticated
USING (true);  -- or more specific: auth.uid() = user_id
```

## Service Role Client Bypasses All RLS

The admin client (`lib/supabase/admin.ts`) uses the service role key which skips all RLS policies. This is intentional but can hide policy bugs:

```typescript
// This query succeeds even if RLS would block it:
const { data } = await supabaseAdmin.from('customers').select('*')

// But this query is subject to RLS:
const { data } = await supabaseBrowser.from('customers').select('*')
```

Always test with the browser/server client during development to verify RLS works correctly. Don't rely on the admin client to confirm data exists.

## Policy Uses `auth.uid()` but User Is Not Authenticated

```sql
CREATE POLICY "Users see own invoices"
ON invoices FOR SELECT
USING (auth.uid() = customer_id);

-- If the client isn't sending the JWT, auth.uid() returns null
-- null = null is false in SQL → no rows returned
```

Debug by checking the JWT is being sent:
```typescript
// Verify the session exists before querying:
const { data: { user } } = await supabase.auth.getUser()
console.log('User:', user?.id)  // null = JWT not being sent
```

## Policy References Wrong Column

```sql
-- WRONG — customer_id column doesn't exist (it's user_id):
CREATE POLICY "Users see own invoices"
ON invoices FOR SELECT
USING (auth.uid() = customer_id);

-- No error — Postgres treats undefined column reference as null
-- Result: all queries return empty

-- CORRECT — verify column name:
CREATE POLICY "Users see own invoices"
ON invoices FOR SELECT
USING (auth.uid() = user_id);
```

Verify column names with `list_tables` MCP tool before writing policies.

## INSERT Policy Missing Column Check

```sql
-- Incomplete INSERT policy — allows creating records for other users:
CREATE POLICY "Users can insert invoices"
ON invoices FOR INSERT
TO authenticated
WITH CHECK (true);  -- any authenticated user can insert anything

-- CORRECT — enforce user_id matches auth:
CREATE POLICY "Users can insert own invoices"
ON invoices FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);
```

## UPDATE Policy Without Row Filter

```sql
-- WRONG — user can update any row (no WHERE filter):
CREATE POLICY "Users can update invoices"
ON invoices FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (auth.uid() = user_id);

-- The USING clause filters which rows the user can update
-- The WITH CHECK clause filters what the updated row can look like
-- CORRECT:
CREATE POLICY "Users can update own invoices"
ON invoices FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)  -- can only update rows they own
WITH CHECK (auth.uid() = user_id);  -- after update, user_id must still match
```

## Soft-Delete Policies

When using `deleted_at` for soft deletes, hide deleted records from all policies:

```sql
-- SELECT policy must exclude soft-deleted:
CREATE POLICY "Users see own non-deleted invoices"
ON invoices FOR SELECT
USING (
  auth.uid() = user_id
  AND deleted_at IS NULL  -- exclude soft-deleted
);
```

Forgetting this makes soft-deleted records still visible.

## Foreign Key with RLS

If table A references table B via FK, and B has RLS, JOINs may return partial data without error:

```sql
-- invoices.customer_id references customers.id
-- If customers has RLS and the user can't see a customer, the JOIN silently excludes those rows

-- This won't error, it just returns invoices without the customer data:
SELECT invoices.*, customers.name
FROM invoices
LEFT JOIN customers ON invoices.customer_id = customers.id
```

Fix: ensure the policy on referenced tables allows access for the same users who can access the referencing table.

## Testing RLS Policies

```sql
-- Test as a specific user:
SET LOCAL role = authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "user-id-here"}';

SELECT * FROM invoices;
-- Should return only that user's invoices
```

Or use Supabase's MCP tool with `execute_sql` using the anon key to verify what anonymous users see.
