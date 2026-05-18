# Cloudflare R2

## What R2 Is

R2 is Cloudflare's S3-compatible object storage. No egress fees (vs S3 which charges per GB downloaded). Use for images, PDFs, exports, and any binary file storage in Cloudflare-hosted projects.

Use R2 when:
- The app runs on Cloudflare Workers (not Vercel)
- You have high-volume downloads (egress savings vs S3)
- You want to serve files directly from the edge without a CDN layer

For Vercel-deployed projects: use Supabase Storage instead.

## Setup

```bash
wrangler r2 bucket create my-files
```

```toml
# wrangler.toml
[[r2_buckets]]
binding = "FILES"
bucket_name = "my-files"
preview_bucket_name = "my-files-dev"
```

## Worker Handler with R2

```typescript
export interface Env {
  FILES: R2Bucket
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)
    const key = url.pathname.slice(1)  // /path/to/file.pdf → path/to/file.pdf
    
    if (request.method === 'GET') {
      const object = await env.FILES.get(key)
      if (!object) return new Response('Not found', { status: 404 })
      
      return new Response(object.body, {
        headers: {
          'Content-Type': object.httpMetadata?.contentType ?? 'application/octet-stream',
          'ETag': object.httpEtag,
          'Cache-Control': 'public, max-age=31536000',
        },
      })
    }
    
    return new Response('Method not allowed', { status: 405 })
  }
}
```

## Uploading Objects

```typescript
// From a Worker (server-side upload):
await env.FILES.put(key, body, {
  httpMetadata: {
    contentType: 'image/jpeg',
    contentDisposition: 'inline',
  },
  customMetadata: {
    userId: user.id,
    uploadedAt: new Date().toISOString(),
  },
})

// From client → presigned upload URL (don't expose R2 binding to client):
const url = await generatePresignedUploadUrl(key, env)
// Client PUT to the presigned URL directly
```

## Generating Presigned Upload URLs

R2 supports presigned URLs via the AWS S3 compatible API (not the Workers binding):

```typescript
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'

const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID!,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
  },
})

async function getUploadUrl(key: string): Promise<string> {
  const command = new PutObjectCommand({
    Bucket: process.env.R2_BUCKET_NAME,
    Key: key,
  })
  return getSignedUrl(s3, command, { expiresIn: 300 })  // 5 minutes
}
```

## Listing and Deleting

```typescript
// List objects with prefix:
const listed = await env.FILES.list({ prefix: `user-${userId}/`, limit: 100 })

for (const obj of listed.objects) {
  console.log(obj.key, obj.size, obj.uploaded)
}

// Delete:
await env.FILES.delete('path/to/file.pdf')

// Delete multiple:
await env.FILES.delete(['file1.pdf', 'file2.pdf'])
```

## Public Bucket vs Access Control

By default R2 buckets are private. For public files (images, public assets):
1. Enable "Public Access" in the R2 bucket settings in Cloudflare dashboard
2. Files are available at `https://pub-<hash>.r2.dev/<key>`
3. Add a custom domain for production: `cdn.yourdomain.com` → R2 bucket

For private files, always serve through your Worker which can apply auth checks before returning the object body.

## R2 vs Supabase Storage Decision

| Factor | R2 | Supabase Storage |
|---|---|---|
| Hosting | Cloudflare Workers | Vercel or any |
| Auth integration | Manual | Supabase RLS policies |
| Real-time | No | No |
| Egress cost | Free | Free to 5GB/month |
| S3 compatible | Yes | Yes |
| Best for | Workers-based apps | Supabase-based apps |
