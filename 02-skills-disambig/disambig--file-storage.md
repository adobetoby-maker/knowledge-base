# Disambiguation: File Storage Options

## Decision Tree

```
Are files private (only accessible to authenticated users)?
  YES → Supabase Storage or S3/R2 with signed URLs
  NO  → Static file host with public CDN

Are you on Cloudflare infrastructure?
  YES → Cloudflare R2 (zero egress cost, S3-compatible API)
  NO  → Supabase Storage (if already using Supabase) or AWS S3

Do files need processing (resize, transcode)?
  YES → Upload to R2/S3, process with Cloudflare Images / Lambda
  NO  → Direct storage

Are files temporary (user uploads that expire)?
  YES → Presigned upload URL + S3 lifecycle policy or manual cleanup
  NO  → Permanent storage

File size?
  < 1MB: Can base64-encode in database (not recommended but works)
  1MB - 5GB: Object storage
  > 5GB: Chunked upload required
```

## Quick Reference

| Solution | Best for | Avoid when |
|----------|----------|-----------|
| Supabase Storage | Already using Supabase, RLS needed | Multi-tenant, large scale |
| Cloudflare R2 | CF Workers stack, cost-sensitive | Need CDN transform features |
| AWS S3 | AWS infrastructure, large scale | Egress costs matter |
| Vercel Blob | Next.js + Vercel, simple needs | Large files, complex access |
| Uploadthing | Next.js, quick integration | Fine-grained access control |

## Supabase Storage

Best when: you have Supabase auth and need per-user access control.

```ts
// Upload
const { data, error } = await supabase.storage
  .from('avatars')
  .upload(`${userId}/avatar.jpg`, file, {
    contentType: file.type,
    upsert: true,
  })

// Public URL (for public buckets)
const { data: { publicUrl } } = supabase.storage
  .from('avatars')
  .getPublicUrl(`${userId}/avatar.jpg`)

// Signed URL (for private buckets, 1 hour expiry)
const { data, error } = await supabase.storage
  .from('documents')
  .createSignedUrl(`${userId}/contract.pdf`, 3600)
```

RLS on storage buckets uses the same policies as database tables. Users can only access their own files.

## Cloudflare R2

Best when: already on Cloudflare Workers stack. Zero egress cost is a major advantage.

```ts
// wrangler.jsonc
{
  "r2_buckets": [{ "binding": "BUCKET", "bucket_name": "uploads" }]
}

// Route Handler (CF Worker)
export async function POST(req: Request) {
  const { env } = getCloudflareContext()
  const formData = await req.formData()
  const file = formData.get('file') as File

  const key = `uploads/${crypto.randomUUID()}-${file.name}`
  await env.BUCKET.put(key, await file.arrayBuffer(), {
    httpMetadata: { contentType: file.type },
  })

  return Response.json({ key })
}

// Generate presigned URL for download (via Cloudflare Images or presigned URL)
const url = await env.BUCKET.createPresignedUrl(key, { expiresIn: 3600 })
```

## Presigned Upload URLs (Direct-to-Storage)

Never route file data through your server — get a presigned URL and upload directly from the browser:

```ts
// Server: generate presigned URL
export async function POST(req: Request) {
  const { filename, contentType } = await req.json()
  const key = `uploads/${Date.now()}-${filename}`

  // S3/R2 presigned URL
  const command = new PutObjectCommand({
    Bucket: process.env.S3_BUCKET,
    Key: key,
    ContentType: contentType,
  })
  const presignedUrl = await getSignedUrl(s3Client, command, { expiresIn: 300 })

  return Response.json({ presignedUrl, key })
}

// Client: upload directly to storage
async function uploadFile(file: File) {
  const { presignedUrl, key } = await fetch('/api/upload-url', {
    method: 'POST',
    body: JSON.stringify({ filename: file.name, contentType: file.type }),
  }).then(r => r.json())

  await fetch(presignedUrl, {
    method: 'PUT',
    body: file,
    headers: { 'Content-Type': file.type },
  })

  return key  // Store this in your database
}
```

## After Upload: What to Store in the Database

Never store the full URL — store the key and reconstruct the URL on read:

```ts
// Wrong: URL may change if you move storage providers
INSERT INTO documents (user_id, url) VALUES (userId, 'https://r2.example.com/uploads/abc.pdf')

// Right: store the key, generate URL on read
INSERT INTO documents (user_id, storage_key, filename) 
  VALUES (userId, 'uploads/abc.pdf', 'contract.pdf')

// Generate URL when needed
const url = `https://r2.example.com/${doc.storageKey}`
// Or signed URL via SDK
```
