# Skill: Document Upload

## Overview

Document upload involves: client-side file validation, direct-to-storage upload (bypassing the server for large files), database record for the upload, and cleanup of orphaned files. The key pattern is presigned URLs — the server authorizes the upload and returns a temporary URL; the client uploads directly to S3/R2/Supabase Storage without the file traversing the app server.

## File Validation (Client)

```ts
const ALLOWED_TYPES = ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'image/png', 'image/jpeg']
const MAX_SIZE_BYTES = 10 * 1024 * 1024  // 10 MB

function validateFile(file: File): string | null {
  if (!ALLOWED_TYPES.includes(file.type)) {
    return `File type not allowed. Accepted: PDF, Word, PNG, JPEG`
  }
  if (file.size > MAX_SIZE_BYTES) {
    return `File too large. Maximum size: ${MAX_SIZE_BYTES / 1024 / 1024}MB`
  }
  return null  // Valid
}
```

Client-side validation is UX only — always re-validate on the server.

## Presigned URL Flow (Supabase Storage)

```ts
// Server: generate presigned upload URL
export async function POST(req: Request) {
  const session = await getServerSession()
  if (!session) return new Response(null, { status: 401 })

  const { filename, contentType, size } = await req.json()

  // Server-side validation
  if (!ALLOWED_TYPES.includes(contentType)) {
    return Response.json({ error: 'Invalid file type' }, { status: 400 })
  }
  if (size > MAX_SIZE_BYTES) {
    return Response.json({ error: 'File too large' }, { status: 400 })
  }

  const key = `uploads/${session.userId}/${Date.now()}-${filename}`

  const { data, error } = await supabaseAdmin.storage
    .from('documents')
    .createSignedUploadUrl(key, { upsert: false })

  if (error) return Response.json({ error: error.message }, { status: 500 })

  // Store pending record
  const [doc] = await db.insert(documents).values({
    userId: session.userId,
    storageKey: key,
    filename,
    contentType,
    sizeBytes: size,
    status: 'pending',
  }).returning()

  return Response.json({ uploadUrl: data.signedUrl, token: data.token, documentId: doc.id })
}
```

```ts
// Client: upload directly to storage using presigned URL
async function uploadDocument(file: File) {
  const error = validateFile(file)
  if (error) throw new Error(error)

  // Get presigned URL
  const { uploadUrl, documentId } = await fetch('/api/documents/upload', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ filename: file.name, contentType: file.type, size: file.size }),
  }).then(r => r.json())

  // Upload directly — no file goes through the app server
  await fetch(uploadUrl, {
    method: 'PUT',
    body: file,
    headers: { 'Content-Type': file.type },
  })

  // Confirm upload
  await fetch(`/api/documents/${documentId}/confirm`, { method: 'POST' })

  return documentId
}
```

## Confirm Upload

```ts
// Server: confirm after successful upload
export async function POST(req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession()
  // Verify ownership
  const doc = await db.query.documents.findFirst({
    where: and(eq(documents.id, params.id), eq(documents.userId, session.userId)),
  })
  if (!doc) return new Response(null, { status: 404 })

  await db.update(documents).set({ status: 'ready' }).where(eq(documents.id, params.id))
  return Response.json({ ok: true })
}
```

## Progress Tracking

```ts
function uploadWithProgress(file: File, uploadUrl: string, onProgress: (pct: number) => void) {
  return new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100))
    })
    xhr.addEventListener('load', () => xhr.status < 400 ? resolve() : reject(new Error(`Upload failed: ${xhr.status}`)))
    xhr.addEventListener('error', () => reject(new Error('Network error')))
    xhr.open('PUT', uploadUrl)
    xhr.setRequestHeader('Content-Type', file.type)
    xhr.send(file)
  })
}
```

`fetch` doesn't support upload progress. Use `XMLHttpRequest` for the upload step if progress is needed.

## Orphan Cleanup

```ts
// Cron: delete pending records older than 1 hour (upload never confirmed)
async function cleanupOrphanedUploads() {
  const stale = await db.select().from(documents).where(
    and(
      eq(documents.status, 'pending'),
      lt(documents.createdAt, new Date(Date.now() - 60 * 60 * 1000))
    )
  )

  for (const doc of stale) {
    await supabaseAdmin.storage.from('documents').remove([doc.storageKey])
    await db.delete(documents).where(eq(documents.id, doc.id))
  }
}
```

## Key Rules

- Presigned URLs (not proxying through the app server) for files over 1MB — the server becomes a bottleneck and adds latency.
- Always validate file type and size server-side — client-side validation is trivially bypassed.
- Store `status: 'pending'` until upload is confirmed — prevents displaying half-uploaded files.
- Use `XMLHttpRequest` (not `fetch`) for upload progress events — the Fetch API has no upload progress callback.
- Clean up orphaned `pending` records on a cron — presigned URL expiry doesn't clean up the DB record.
