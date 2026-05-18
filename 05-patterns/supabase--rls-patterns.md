# Supabase RLS Patterns — Row Level Security

**When:** Setting up permissions on Supabase tables. Controlling who can read, write, update, delete rows.
**Rule:** RLS is a database-level permission system. Policies are SQL expressions evaluated for each row. A missing policy = no access for that operation.

## The Core Pattern — User Owns Their Data
```sql
-- Enable RLS (required first)
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- SELECT: user sees their own rows
CREATE POLICY "select_own" ON public.posts
  FOR SELECT USING (auth.uid() = user_id);

-- INSERT: user creates rows with their own user_id
CREATE POLICY "insert_own" ON public.posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- UPDATE: user updates their own rows
CREATE POLICY "update_own" ON public.posts
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: user deletes their own rows
CREATE POLICY "delete_own" ON public.posts
  FOR DELETE USING (auth.uid() = user_id);
```
`USING` = filter which existing rows the user can see/modify
`WITH CHECK` = validate the NEW data being written

## Public Read, Auth Write
```sql
CREATE POLICY "public_read" ON public.products
  FOR SELECT USING (true);  -- anyone can read

CREATE POLICY "auth_insert" ON public.products
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);  -- logged in users can add
```

## Admin Can See Everything
```sql
-- Uses custom claims or a separate admins table
CREATE POLICY "admin_all" ON public.posts
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.admins WHERE user_id = auth.uid()
    )
  );
```

## Tenant Isolation (Multi-tenant SaaS)
```sql
-- Users only see rows for their organization
CREATE POLICY "tenant_isolation" ON public.invoices
  FOR SELECT USING (
    org_id IN (
      SELECT org_id FROM public.org_members WHERE user_id = auth.uid()
    )
  );
```

## Published vs Draft Content
```sql
-- Public can see published; authors see their own drafts
CREATE POLICY "read_published_or_own" ON public.articles
  FOR SELECT USING (
    status = 'published' OR auth.uid() = author_id
  );
```

## Policy Debugging Workflow
```sql
-- 1. Check if RLS is on
SELECT relrowsecurity FROM pg_class WHERE relname = 'your_table';
-- true = RLS enabled

-- 2. List policies
SELECT * FROM pg_policies WHERE tablename = 'your_table';

-- 3. Simulate a user's access in SQL editor
SET LOCAL role = authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "user-uuid-here"}';
SELECT * FROM public.your_table;

-- 4. Run as service role (bypass RLS) to confirm data exists
SET role = postgres;
SELECT * FROM public.your_table;
```

## Service Role Bypasses RLS
Using `SUPABASE_SERVICE_ROLE_KEY` creates a client that bypasses ALL policies.
- Use for: admin operations, migrations, server-to-server
- NEVER in client components or exposed endpoints

## Common Mistake: Forgetting INSERT Policy
```
User can SELECT their data ✓
User tries INSERT → empty result, no error
```
This happens because without an INSERT policy, the row silently fails (not an error).
Always define policies for ALL four operations your app uses.
