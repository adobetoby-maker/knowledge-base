# Disambig: File Upload Approach

## Key Question: Where Does the File Go?

This determines the architecture. Answer this first.

| Destination | Approach |
|-------------|---------|
| Supabase Storage | Direct upload via `supabase.storage.from().upload()` |
| S3 / R2 | Signed URL from server, then PUT direct from browser |
| Server filesystem (DO NOT) | Never — ephemeral, not scalable |
| Cloudflare R2 (from Worker) | Workers native `BUCKET.put()` |

## Choose: Direct Client Upload (Supabase)

Best for 80% of cases — files under 50MB, Supabase project.

```
Browser → FormData → Route Handler → supabase.storage.upload()
OR
Browser → Supabase signed URL → Supabase Storage (direct)
```

Use when: user uploads profile photos, documents, CSV imports, invoice attachments.

## Choose: Signed URL Upload (S3/R2)

Best for large files or AWS infrastructure.

```
Browser → GET /api/signed-upload → Server generates signed URL → 
Browser PUT file to URL → Server confirms in DB
```

Use when: files >50MB, video uploads, existing AWS infrastructure, Cloudflare R2.

## Choose: Server-Side Processing Required

When the file must be processed before storage (resize, parse, validate):

```
Browser → POST file → Route Handler → Process (Sharp/csv-parse) → Store result
```

Use when: image resize/format conversion, CSV import with validation, PDF generation.

## File Type Decision

| Content type | Upload pattern | Library |
|-------------|---------------|---------|
| Profile photos | Supabase direct + Sharp resize | `sharp` |
| CSV imports | Server parse + validate | `csv-parse` |
| Documents (PDF, etc.) | Direct to storage, signed URL to view | Supabase Storage |
| Videos | Signed URL to Cloudflare Stream | CF Stream API |
| Spreadsheets | Server parse | `xlsx` |

## Component Choice

| Requirement | Component |
|------------|----------|
| Simple file button | `<input type="file">` |
| Drag and drop | `react-dropzone` |
| Resumable (large files) | `tus-js-client` |
| Multi-file with preview | Custom with `react-dropzone` |

## Validation Location

Always validate on the server regardless of client validation:

| Check | Client | Server |
|-------|--------|--------|
| File type | Optional UX | Required |
| File size | Optional UX | Required |
| Content validity | No | Required (read metadata) |
| Auth | No | Required |

Client validation is a UX convenience only. Never skip server validation.

## File Size Limits

Vercel serverless functions: **4.5MB** request body limit.

For files larger than 4.5MB, use signed URL upload (browser uploads directly to storage, bypassing the API server). If processing is needed, fetch from storage in a background job.

## Temporary Files

```ts
// For processing-then-delete pattern
const tmpPath = `/tmp/${crypto.randomUUID()}-${file.name}`
// Process...
// fs.unlinkSync(tmpPath)  // Always clean up
```

`/tmp` is available in Vercel and Cloudflare Workers (limited). Don't rely on it persisting between requests.

## RLS for Storage

Always set RLS policies on Supabase Storage buckets. Private bucket + RLS = users can only access their own files:

```sql
-- Allow users to CRUD their own files
CREATE POLICY "users can upload own files"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'uploads' AND auth.uid()::text = (storage.foldername(name))[1]);
```

The folder name convention `{userId}/filename.pdf` enables RLS based on path prefix.
