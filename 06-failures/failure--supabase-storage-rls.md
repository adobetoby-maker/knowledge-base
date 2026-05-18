# Failure: Supabase Storage RLS Pitfalls

## Overview
Supabase Storage has a separate policy system from database tables. Managing storage permissions in the SQL editor affects tables, not storage — storage policies must be set in the Storage dashboard or via the `storage.objects` table with specific policy functions. The most common failures: forgetting that public buckets bypass all policies entirely, using the wrong helper functions for path-based access, and not realizing that the `SERVICE_ROLE` key bypasses everything.

## Storage Policies vs Table Policies

Database table policies are in `public` schema. Storage policies are on `storage.objects`:

```sql
-- This is a TABLE policy (affects a database table)
CREATE POLICY "users can read own rows"
  ON public.documents FOR SELECT
  USING (auth.uid() = user_id);

-- This is a STORAGE policy (affects uploaded files)
CREATE POLICY "users can upload own files"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

You cannot manage storage policies from the Table Editor — use the Storage dashboard or SQL on `storage.objects` directly.

## Public vs Private Buckets

```sql
-- Public bucket: anyone can read ANY file, regardless of policies
-- INSERT/UPDATE/DELETE still require policies
UPDATE storage.buckets SET public = true WHERE id = 'product-images';

-- Private bucket: all operations require matching policies
UPDATE storage.buckets SET public = false WHERE id = 'user-documents';
```

A public bucket set via the dashboard bypasses all SELECT policies. This is intentional for CDN-served assets but catastrophic for user documents.

## Path-Based Access with Helper Functions

```sql
-- storage.foldername(name) returns array of path segments
-- For file at 'user-uploads/abc123/photo.jpg':
-- storage.foldername('user-uploads/abc123/photo.jpg') = ['user-uploads', 'abc123']
-- storage.filename('user-uploads/abc123/photo.jpg') = 'photo.jpg'

-- Users can only access files in their own folder (folder named by user ID)
CREATE POLICY "user folder access"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'user-uploads' AND
    auth.uid()::text = (storage.foldername(name))[1]
  )
  WITH CHECK (
    bucket_id = 'user-uploads' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

The path pattern `user-uploads/{user_id}/filename.ext` enables this policy. If you store files at `user-uploads/filename.ext` (no user subfolder), path-based policies cannot differentiate users.

## `auth.uid()` in Storage Policies

```sql
-- auth.uid() works in storage policies — same as table policies
CREATE POLICY "authenticated uploads"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'documents' AND
    auth.role() = 'authenticated'
  );

-- Match file ownership via joined table
CREATE POLICY "owner can read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'invoices' AND
    EXISTS (
      SELECT 1 FROM invoices
      WHERE invoices.storage_path = name
        AND invoices.user_id = auth.uid()
    )
  );
```

## SERVICE_ROLE Key Bypasses Everything

```ts
// Admin client with service role bypasses all storage policies
const adminClient = createClient(url, process.env.SUPABASE_SERVICE_ROLE_KEY!)

// This upload succeeds regardless of bucket policies
await adminClient.storage.from('private-bucket').upload('any/path.pdf', buffer)
```

This is intentional for server-side admin operations. Never use the service role key in client-side code.

## Debugging Storage Policies

```sql
-- Check policies on storage.objects
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'objects' AND schemaname = 'storage';

-- Test as a specific user
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "user-uuid-here", "role": "authenticated"}';
SELECT * FROM storage.objects WHERE bucket_id = 'your-bucket';
RESET ROLE;
```

## Key Rules
- Storage policies are separate from table policies — manage in Storage dashboard or SQL on `storage.objects`
- Public bucket = public read for ALL files in that bucket — use only for non-sensitive assets
- Always structure file paths as `{user_id}/filename` to enable path-based user isolation
- `USING` clause = who can SELECT/DELETE; `WITH CHECK` clause = who can INSERT/UPDATE
- Anon key + private bucket = policy-gated access; service role = full bypass
- Test storage policies with the Supabase Storage policy editor before deploying
- Four operations need separate policies: SELECT, INSERT, UPDATE, DELETE — check all four
