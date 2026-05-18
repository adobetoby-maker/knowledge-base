# Supabase Storage Common Failures

## 1. Bucket Not Public but URL Accessed Publicly

**Symptom:** Image URL returns 400 or 403, even with a valid public URL from `getPublicUrl()`.

**Cause:** `getPublicUrl()` generates a public URL format, but if the bucket is set to PRIVATE, accessing that URL returns an error. The bucket must be PUBLIC for public URLs to work.

**Fix:**
```typescript
// Option 1: Make the bucket public in Supabase dashboard
// Storage → Buckets → [bucket name] → Make Public

// Option 2: Use signed URLs for private files (expires after N seconds)
const { data: { signedUrl } } = await supabase.storage
  .from('private-files')
  .createSignedUrl('path/to/file.pdf', 3600)  // 1 hour expiry

// Option 3: Proxy downloads through API route (most control)
// GET /api/files/[id] → auth check → signed URL → redirect
```

## 2. RLS Blocking Uploads

**Symptom:** Upload returns 403 or "Row Level Security policy violation" even with valid user session.

**Cause:** Storage buckets have RLS policies just like tables. No policy = no access for non-service-role.

**Check policies:**
```sql
-- Check storage policies
SELECT policyname, definition
FROM storage.policies
WHERE bucket_id = 'your-bucket-name';
```

**Fix — allow authenticated users to upload to their own folder:**
```sql
-- Upload policy: authenticated users can upload to user_id/ prefix
CREATE POLICY "Authenticated users can upload to own folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Read policy: public read for avatar bucket
CREATE POLICY "Public can read avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');
```

## 3. File Size Limits

**Symptom:** Large uploads fail with "Payload too large" or similar.

**Cause:** Supabase has default file size limits. Next.js also has a body size limit for route handlers.

**Fix:**
```typescript
// Increase Next.js body size limit for upload route
export const config = {
  api: {
    bodyParser: {
      sizeLimit: '10mb',
    },
  },
}

// Or in App Router, Next.js 15+ respects the browser's FormData stream
// — no config needed for streaming uploads
```

Also check Supabase project settings → Storage → File size limit.

## 4. CORS Issues with Direct Browser Uploads

**Symptom:** Browser console shows CORS error when uploading directly to Supabase Storage.

**Cause:** Supabase Storage respects CORS settings. The allowed origins must include your domain.

**Fix:** In Supabase dashboard → Storage → CORS, add your domain to the allowed origins.

For development: add `http://localhost:3000`.
For production: add `https://yourdomain.com`.

## 5. Path Characters Breaking URLs

**Symptom:** Uploaded file has spaces or special characters in name, URL doesn't work.

**Cause:** Special characters in file paths must be URL-encoded.

**Fix:** Sanitize filenames before upload:
```typescript
const safeFileName = file.name
  .replace(/[^a-zA-Z0-9.-]/g, '_')  // replace special chars with underscores
  .replace(/_{2,}/g, '_')            // collapse multiple underscores
  .toLowerCase()                      // normalize case

const path = `${userId}/${Date.now()}-${safeFileName}`
await supabase.storage.from('uploads').upload(path, file)
```

## 6. getPublicUrl Returns Incorrect URL

**Symptom:** `getPublicUrl()` returns a URL but it 404s.

**Cause:** The file path passed to `getPublicUrl()` doesn't match the actual path the file was uploaded to.

**Debug:**
```typescript
// Log the path used in upload
console.log('Uploaded to path:', path)

// Verify the public URL uses the same path
const { data: { publicUrl } } = supabase.storage.from('uploads').getPublicUrl(path)
console.log('Public URL:', publicUrl)

// Also verify via the dashboard: Storage → Files → navigate to the file
```

## 7. Missing `Content-Type` Causes Browser Issues

**Symptom:** PDF opens as download instead of inline, or image shows broken.

**Cause:** `Content-Type` not set during upload — defaults to `application/octet-stream`.

**Fix:**
```typescript
await supabase.storage.from('bucket').upload(path, file, {
  contentType: file.type,  // e.g., 'image/png', 'application/pdf'
})
```

For server-side uploads where you have a buffer but not a `File` object:
```typescript
await supabase.storage.from('bucket').upload(path, buffer, {
  contentType: 'application/pdf',  // must specify explicitly
})
```
