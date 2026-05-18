# Failure: Supabase Storage Errors

## Problem: 403 Uploading to Storage

**Symptom**: `StorageApiError: Bucket not found` or `StorageApiError: not allowed`.

**Root cause 1**: Bucket doesn't exist. Create it:
```ts
// Create bucket if it doesn't exist (run once, or in migration)
const { error } = await supabaseAdmin.storage.createBucket('avatars', {
  public: false,
  allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
  fileSizeLimit: 5 * 1024 * 1024,  // 5MB
})
```

**Root cause 2**: Storage RLS policy missing:
```sql
-- Users can upload to their own folder
CREATE POLICY "users can upload own files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Users can read their own files
CREATE POLICY "users can read own files"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'avatars'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
```

**Root cause 3**: Using the anon/browser client for a private bucket upload. Private bucket uploads require an authenticated client.

## Problem: Public URL Returns 400 or Garbled Content

**Symptom**: `getPublicUrl()` returns a URL that returns 400 Bad Request.

**Root cause 1**: Bucket is not set to public. Either:
1. Update bucket to public: `await supabaseAdmin.storage.updateBucket('bucket-name', { public: true })`
2. Or use signed URLs instead of public URLs for private buckets

```ts
// For private buckets, use signed URLs (expire after duration)
const { data: signedData } = await supabase.storage
  .from('private-docs')
  .createSignedUrl(path, 3600)  // Expires in 1 hour

const { signedUrl } = signedData!
```

**Root cause 2**: Path has a leading slash. Supabase storage paths must NOT start with `/`:
```ts
// BAD:
const path = `/avatars/${userId}.jpg`
supabase.storage.from('bucket').upload(path, file)

// GOOD:
const path = `avatars/${userId}.jpg`  // No leading slash
```

## Problem: Upsert Not Overwriting

**Symptom**: Uploading the same file path again creates a duplicate instead of overwriting.

**Root cause**: Missing `upsert: true` option:

```ts
// BAD: creates duplicate or errors on conflict
await supabase.storage.from('bucket').upload(path, file)

// GOOD: overwrites existing file at the same path
await supabase.storage.from('bucket').upload(path, file, { upsert: true })
```

## Problem: Public CDN Serving Stale File After Upsert

**Symptom**: Updated file at same path, but old version is still served.

**Root cause**: Supabase CDN caches by path, not content hash. Upsert updates the storage object but the CDN serves the old cached version until expiry.

**Fix**: Add a cache-busting query parameter after upsert:
```ts
await supabase.storage.from('bucket').upload(path, file, { upsert: true })

const { data: { publicUrl } } = supabase.storage.from('bucket').getPublicUrl(path)
const cacheBusted = `${publicUrl}?v=${Date.now()}`  // Save this URL

// Store cacheBusted URL in DB, not the base URL
await supabase.from('profiles').update({ avatar_url: cacheBusted }).eq('id', userId)
```

## Problem: File Size Limit Exceeded

**Symptom**: `PayloadTooLargeError` or similar, even when your file is within the bucket's `fileSizeLimit`.

**Root cause**: There's a platform-level file size limit in addition to the bucket setting. Supabase free tier: 50MB. Pro: 500MB.

**Fix**: Compress client-side before upload for large images:
```ts
// Browser-side canvas compression before upload
async function compressImage(file: File, maxWidthPx = 1200): Promise<Blob> {
  const img = await createImageBitmap(file)
  const ratio = Math.min(1, maxWidthPx / img.width)
  const canvas = new OffscreenCanvas(img.width * ratio, img.height * ratio)
  const ctx = canvas.getContext('2d')!
  ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
  return await canvas.convertToBlob({ type: 'image/webp', quality: 0.85 })
}
```

## Problem: Download URL Expires Mid-Session

**Symptom**: Signed URL worked when page loaded, but after 1 hour it returns 401.

**Root cause**: Signed URLs have a TTL. If the user has the page open past the TTL, all image `src` attributes break.

**Fix**:
1. Use a longer TTL: `createSignedUrl(path, 86400)` for 24 hours
2. Or make the bucket public and use `getPublicUrl()` instead
3. Or refresh the signed URL before expiry (complex, usually not worth it)
4. Or serve via your own Route Handler that generates a fresh URL on each request (best for very sensitive content)
