# Disambig: File Storage Approach

## Decision Tree

**What kind of file?**
- Static asset (logo, product image, fixed document) → public folder or Vercel CDN
- User-uploaded file → Supabase Storage (S3-compatible)
- Generated file (PDF invoice, CSV export) → generate on demand, stream to user

**Does it need access control?**
- No (public URL is fine) → Supabase Storage public bucket
- Yes (only the owner can download) → Supabase Storage private bucket + signed URLs

**How large?**
- < 10MB → Supabase Storage, direct upload
- > 10MB → Supabase Storage with chunked upload, or presigned S3 upload

## Supabase Storage (User Uploads)

```typescript
// Upload:
const { data, error } = await supabase.storage
  .from('invoices')          // bucket name
  .upload(`${userId}/${filename}`, file, {
    contentType: file.type,
    upsert: false,            // don't overwrite
  })

if (error) throw error

// Get public URL (public bucket only):
const { data: { publicUrl } } = supabase.storage
  .from('invoices')
  .getPublicUrl(data.path)

// Get signed URL (private bucket, expires in 1 hour):
const { data: { signedUrl } } = await supabase.storage
  .from('invoices')
  .createSignedUrl(data.path, 3600)
```

## Public vs Private Bucket

**Public bucket:**
- URL is accessible to anyone with the link
- No auth required to read
- Use for: product images, logos, public documents

**Private bucket:**
- URL requires a signed token
- Use for: invoices, contracts, user-uploaded documents
- Always generate signed URLs server-side (not client-side — exposes service role key)

## Storing File References in DB

Store the path, not the full URL — the base URL can change:

```sql
-- WRONG — stores full URL:
ALTER TABLE invoices ADD COLUMN attachment_url text;
-- https://xyz.supabase.co/storage/v1/object/public/invoices/user123/file.pdf

-- CORRECT — stores path only:
ALTER TABLE invoices ADD COLUMN attachment_path text;
-- invoices/user123/file.pdf

-- Reconstruct URL in application code when needed
```

## Generated Files (PDF, CSV)

Don't store generated files unless they're large or need audit history. Generate on demand:

```typescript
// Route Handler that generates and streams a CSV:
// app/api/invoices/export/route.ts
export async function GET(request: Request) {
  const invoices = await fetchInvoices()
  const csv = generateCSV(invoices)
  
  return new Response(csv, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': 'attachment; filename="invoices.csv"',
    },
  })
}
```

## File Type Validation

Always validate on the server, not just the client:

```typescript
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
const MAX_SIZE = 10 * 1024 * 1024  // 10MB

function validateFile(file: File): string | null {
  if (!ALLOWED_TYPES.includes(file.type)) return 'File type not allowed'
  if (file.size > MAX_SIZE) return 'File too large (max 10MB)'
  return null
}
```

Client validation is UX; server validation is security. Never skip the server check.
