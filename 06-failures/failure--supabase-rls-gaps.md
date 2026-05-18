# Failure: Supabase RLS Gaps

## What RLS Is and Isn't

RLS (Row Level Security) is Postgres's per-row access control. When enabled on a table, every query goes through policy evaluation. Without policies, RLS blocks ALL access (even for the table owner via anon key).

RLS is a safety net — not a replacement for server-side auth checks. Always validate auth in Route Handlers too.

## Gap 1: Table Created Without Enabling RLS

```sql
-- WRONG — no RLS = no row restrictions (unless service role)
CREATE TABLE invoices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  ...
);

-- CORRECT — always enable on all tables with user data
CREATE TABLE invoices (...);
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
```

Without `ENABLE ROW LEVEL SECURITY`, any anon or authenticated request can read/write all rows.

## Gap 2: Policy Covers Wrong Operations

```sql
-- WRONG — only SELECT is protected; any user can INSERT/UPDATE/DELETE
CREATE POLICY "users see own invoices" ON invoices
  FOR SELECT USING (auth.uid() = user_id);

-- CORRECT — separate policies for each operation
CREATE POLICY "users can select own invoices" ON invoices
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users can insert own invoices" ON invoices
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can update own invoices" ON invoices
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own invoices" ON invoices
  FOR DELETE USING (auth.uid() = user_id);
```

The `FOR SELECT` policy only protects reads. Inserts and updates need their own `WITH CHECK` policy. Use `FOR ALL` for simpler cases when all operations have the same rule.

## Gap 3: USING vs WITH CHECK Confusion

```sql
-- USING: filters which rows are visible/affected
-- WITH CHECK: validates the NEW row state after mutation

-- WRONG — UPDATE policy without WITH CHECK allows changing user_id
CREATE POLICY "update own" ON invoices FOR UPDATE
  USING (auth.uid() = user_id);
-- User could UPDATE SET user_id = 'other-user-id' and reassign ownership!

-- CORRECT — both USING and WITH CHECK on UPDATE
CREATE POLICY "update own" ON invoices FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

`USING` determines which rows can be targeted. `WITH CHECK` validates what the row will look like after the update. Both are needed to prevent ownership hijacking.

## Gap 4: Anon Access When Expecting Auth

```sql
-- WRONG — this policy allows ANONYMOUS users to read all invoices
CREATE POLICY "public read" ON invoices FOR SELECT USING (true);

-- CORRECT — require authentication
CREATE POLICY "auth read" ON invoices FOR SELECT USING (auth.uid() IS NOT NULL);

-- Or specific user scope
CREATE POLICY "own invoices" ON invoices FOR SELECT USING (auth.uid() = user_id);
```

`USING (true)` means "everyone." `USING (auth.uid() IS NOT NULL)` means "any authenticated user." Only use `(true)` for genuinely public tables (product catalog, pricing).

## Gap 5: Missing Policy for Service Role Bypass

```ts
// Service role bypasses ALL RLS — be explicit about this
const supabaseAdmin = createClient(url, process.env.SUPABASE_SERVICE_ROLE_KEY!)
// This client ignores ALL RLS policies
// ONLY use for admin operations that intentionally need full access
```

The service role client (using `SUPABASE_SERVICE_ROLE_KEY`) bypasses RLS entirely. Never use it client-side. In server code, use the regular auth client unless you explicitly need to bypass RLS.

## Gap 6: Recursive Policy (Performance)

```sql
-- WRONG — recursive: policy references same table it protects
CREATE POLICY "org members see invoices" ON invoices FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM org_members WHERE user_id = auth.uid()
    )
  );
-- This runs a subquery on org_members for EVERY row scan — very slow

-- CORRECT — use a security definer function to cache
CREATE OR REPLACE FUNCTION user_org_ids()
RETURNS UUID[] AS $$
  SELECT ARRAY(SELECT org_id FROM org_members WHERE user_id = auth.uid())
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE POLICY "org members see invoices" ON invoices FOR SELECT
  USING (org_id = ANY(user_org_ids()));
```

`STABLE` function result is cached per query execution — much faster than inline subqueries that re-run for each row.

## Gap 7: Public Access on Storage Bucket

```sql
-- Storage objects also need RLS
CREATE POLICY "users can upload own files"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'invoices'
  AND auth.uid()::text = (storage.foldername(name))[1]
  -- Requires files to be at path: {userId}/filename.pdf
);

CREATE POLICY "users can read own files"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'invoices'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
```

If the bucket is "public" in Supabase settings, storage.objects RLS is bypassed — anyone with the URL can download the file. Use private buckets + RLS + signed URLs for user files.

## Auditing RLS Coverage

```sql
-- Check which tables have RLS enabled
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY rowsecurity, tablename;

-- List all policies
SELECT tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename;
```

Tables with `rowsecurity = false` in user data schemas are a security risk.
