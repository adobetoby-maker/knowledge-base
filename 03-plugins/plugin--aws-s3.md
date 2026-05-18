# Plugin: AWS S3 (via @aws-sdk/client-s3)

## What It Is

AWS S3 is object storage. Use when: larger files (>50MB), existing AWS infrastructure, signed URL downloads for private files, multi-region replication. For projects already on Vercel + Supabase, use Supabase Storage (simpler). Use S3 for: logistics docs, medical records, large media.

## Installation

```bash
npm install @aws-sdk/client-s3 @aws-sdk/s3-request-presigner
```

## Client Setup

```ts
// lib/s3.ts
import 'server-only'
import { S3Client } from '@aws-sdk/client-s3'

export const s3 = new S3Client({
  region: process.env.AWS_REGION!,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
})

export const BUCKET = process.env.AWS_S3_BUCKET!
```

`import 'server-only'` — credentials must never reach the browser.

## Upload a File

```ts
import { PutObjectCommand } from '@aws-sdk/client-s3'
import { s3, BUCKET } from '@/lib/s3'

export async function uploadFile(
  key: string,
  body: Buffer | Uint8Array,
  contentType: string
) {
  await s3.send(
    new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,          // e.g., 'documents/invoices/inv-1042.pdf'
      Body: body,
      ContentType: contentType,
      ServerSideEncryption: 'AES256',  // Encrypt at rest
    })
  )
}
```

## Generate Signed Download URL

```ts
import { GetObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'

export async function getSignedDownloadUrl(key: string, expiresInSeconds = 3600): Promise<string> {
  const command = new GetObjectCommand({
    Bucket: BUCKET,
    Key: key,
    ResponseContentDisposition: `attachment; filename="${key.split('/').pop()}"`,
  })

  return getSignedUrl(s3, command, { expiresIn: expiresInSeconds })
}
```

Signed URLs work even for private buckets — the signature authorizes the specific request. They expire after `expiresIn` seconds. Use for: document downloads, invoice PDFs, user file access.

## Generate Signed Upload URL (Client-Side Upload)

```ts
import { PutObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'

export async function getSignedUploadUrl(
  key: string,
  contentType: string
): Promise<string> {
  const command = new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    ContentType: contentType,
  })

  return getSignedUrl(s3, command, { expiresIn: 300 })  // 5 min to upload
}
```

Client-side upload flow:
1. Client requests a signed upload URL from Route Handler
2. Route Handler validates auth, generates URL, returns it
3. Client `PUT`s directly to S3 using the signed URL
4. S3 stores the file
5. Client notifies server of successful upload (update DB)

This keeps credentials server-side and skips routing large files through your server.

## Delete a File

```ts
import { DeleteObjectCommand } from '@aws-sdk/client-s3'

export async function deleteFile(key: string) {
  await s3.send(
    new DeleteObjectCommand({
      Bucket: BUCKET,
      Key: key,
    })
  )
}
```

## List Files

```ts
import { ListObjectsV2Command } from '@aws-sdk/client-s3'

export async function listFiles(prefix: string) {
  const response = await s3.send(
    new ListObjectsV2Command({
      Bucket: BUCKET,
      Prefix: prefix,
      MaxKeys: 100,
    })
  )

  return response.Contents?.map((obj) => ({
    key: obj.Key!,
    size: obj.Size!,
    lastModified: obj.LastModified!,
  })) ?? []
}
```

## Bucket Policy for Private Files

Bucket should be private (default). Block all public access:

```json
{
  "BlockPublicAcls": true,
  "IgnorePublicAcls": true,
  "BlockPublicPolicy": true,
  "RestrictPublicBuckets": true
}
```

All access via signed URLs. Never make buckets containing user data public.

## Env Variables

```
AWS_REGION=us-west-2
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_S3_BUCKET=my-app-documents
```

Use IAM policies to restrict the access key to specific bucket operations only (GetObject, PutObject, DeleteObject on the specific bucket — not `*`).

## S3 vs Supabase Storage

| | S3 | Supabase Storage |
|--|---|---|
| Setup | Manual (IAM, bucket, policy) | One click |
| RLS integration | Manual (token-based) | Built-in with Supabase auth |
| Price | $0.023/GB + transfer | Free 1GB, $0.021/GB after |
| Best for | AWS ecosystem, >50MB files | Supabase projects |
