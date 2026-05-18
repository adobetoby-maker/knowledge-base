# MCP: Supabase Storage Workflows

## List Buckets and Files

Before working with storage, check existing buckets:

```typescript
// Use mcp__plugin_supabase_supabase__execute_sql to query storage:
const sql = `
  SELECT bucket_id, name, metadata, created_at
  FROM storage.objects
  WHERE bucket_id = 'blueprints'
  ORDER BY created_at DESC
  LIMIT 20
`
```

Or check bucket policies:
```sql
SELECT * FROM storage.buckets;
```

## Create a Bucket

Use `execute_sql` for bucket creation (not available as direct MCP tool):

```sql
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'images',
  'images',
  true,          -- public = anyone can read via URL
  5242880,       -- 5MB max file size
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
);
```

## Storage RLS Policies

After creating a bucket, add RLS policies via `apply_migration`:

```sql
-- Allow authenticated users to upload to their own folder:
CREATE POLICY "Users can upload own images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow public read for public bucket:
CREATE POLICY "Public images are accessible"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'images');

-- Allow users to delete their own uploads:
CREATE POLICY "Users can delete own images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

## Upload Pattern (Service Role)

For admin/batch uploads that bypass user ownership:

```typescript
// From batch script or admin route (uses service role client):
const { data, error } = await supabaseAdmin.storage
  .from('blueprints')
  .upload(`${siteId}.json`, JSON.stringify(blueprint), {
    contentType: 'application/json',
    upsert: true,  // overwrite if exists
  })
```

## Get Public URL

```typescript
const { data } = supabase.storage.from('images').getPublicUrl('path/to/image.webp')
// Returns: https://PROJECT_ID.supabase.co/storage/v1/object/public/images/path/to/image.webp
```

## Storage for manage-worker-bee Blueprints

The manage-worker-bee app uses a `blueprints` bucket. Each blueprint is a JSON file named `{siteId}.json`:

```sql
-- Check existing blueprints:
SELECT bucket_id, name, created_at
FROM storage.objects
WHERE bucket_id = 'blueprints'
ORDER BY created_at DESC;

-- Check file size of a specific blueprint:
SELECT name, octet_length(metadata::text) as size_bytes
FROM storage.objects
WHERE bucket_id = 'blueprints' AND name = 'some-site-id.json';
```

## Debug: File Not Found vs Permissions Error

Supabase storage returns the same 404 error for both "file doesn't exist" and "RLS policy blocks access". To distinguish:

1. Try downloading via the service role client (bypasses RLS)
2. If service role can access it but anon/user can't: RLS policy issue
3. If service role also gets 404: file doesn't exist

```typescript
// Debug with service role:
const { data, error } = await supabaseAdmin.storage
  .from('blueprints')
  .download(`${siteId}.json`)

if (error) {
  console.log('Error with admin client:', error.message)
  // If still 404: file doesn't exist
  // If 200: was an RLS issue
}
```

## Storage Cleanup Job

Orphaned files (blueprints for deleted sites) can be found with:

```sql
-- Files in storage without a matching site:
SELECT obj.name
FROM storage.objects obj
LEFT JOIN sites s ON obj.name = s.id::text || '.json'
WHERE obj.bucket_id = 'blueprints'
  AND s.id IS NULL;
```
