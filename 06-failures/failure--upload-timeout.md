# File Upload Timing Out on Large Files

Upload timeouts are a class of failure with a specific shape: small files work fine, large files fail partway through. The failure point depends on which timeout fires first — browser, reverse proxy, application server, or serverless function. Each has a different limit, and they're all in the chain.

## Timeout Chain for Proxied Uploads

When a file upload goes through your server (browser → CDN/proxy → your server → storage), timeouts stack:

- **Browser**: no explicit limit for fetch/XHR, but connection will drop if it appears stalled
- **Vercel/serverless functions**: 10s on Hobby, 60s on Pro, 300s on Enterprise for streaming. A 100MB upload at 10MB/s takes 10s just for transfer — barely fits the Pro limit, and doesn't account for processing time
- **Reverse proxy** (Nginx, Cloudflare): Cloudflare has a 100-second request timeout on all plans; Nginx default `proxy_read_timeout` is 60s
- **Your application server**: body parser size limits (Next.js default is 4MB for API routes)

Any one of these can fire first. The user sees a network error or the upload just stops.

## Solution 1: Direct-to-Storage via Presigned URLs

The cleanest solution for large files: bypass your server entirely. Generate a presigned PUT URL from your storage provider (S3, R2, Supabase Storage) and have the browser upload directly to the bucket.

```ts
// Server: generate a presigned URL (valid for 10 minutes)
const url = await s3.getSignedUrlPromise('putObject', {
  Bucket: process.env.S3_BUCKET,
  Key: `uploads/${userId}/${filename}`,
  ContentType: mimeType,
  Expires: 600,
});
// Return URL to browser

// Browser: PUT directly to S3
await fetch(presignedUrl, { method: 'PUT', body: file });
```

Your server is only involved in generating the URL (fast, no timeout risk) and in post-upload processing triggered by a webhook or the client confirming completion. The upload itself flows browser → S3, which has no application-level timeout.

## Solution 2: Chunked Upload with Resume

For very large files (>500MB) or unreliable connections, chunked upload allows resume after interruption:

- Split the file into chunks (e.g., 5MB each)
- Upload each chunk sequentially or in parallel
- Track which chunks succeeded; on retry, skip completed chunks
- Reassemble on completion (S3 multipart upload handles this natively)

S3's multipart upload API is designed for this. Initiate with `CreateMultipartUpload`, upload parts with `UploadPart`, complete with `CompleteMultipartUpload`. Each part is independent — a failed part is retried alone, not the entire file.

## Maximum File Size Enforcement Before Upload Starts

Validate file size on the client before the upload begins. A size check that happens after a failed 5-minute upload is a terrible UX.

```ts
const MAX_SIZE_BYTES = 50 * 1024 * 1024; // 50MB
if (file.size > MAX_SIZE_BYTES) {
  setError(`File too large. Maximum size is 50MB.`);
  return;
}
```

Also enforce server-side (the client check is bypassable). For presigned URL flows, include the `ContentLengthRange` condition in the presigned URL policy to prevent uploads larger than the limit from ever reaching storage.

## Progress Events

Upload progress is available via `XMLHttpRequest.upload.onprogress` or Fetch with a `ReadableStream` body. Show progress for any upload that might take more than 2 seconds.

For presigned direct-to-S3 uploads, use XHR (not fetch) if you need progress events — `fetch` doesn't natively expose upload progress without the `ReadableStream` workaround.

## Next.js Specific: Body Size Limit

Next.js API routes have a 4MB body size limit by default. For any upload through an API route:

```ts
export const config = {
  api: {
    bodyParser: {
      sizeLimit: '50mb',
    },
  },
};
```

But even with an increased limit, routing large uploads through Vercel serverless functions hits function duration limits. Prefer presigned direct-to-S3 for any file over 10MB.

## Key Rules

- For files >10MB, use presigned direct-to-storage uploads (S3/R2/Supabase); don't proxy through the server
- Timeout is a chain — browser, proxy, serverless function, and application server all have independent limits
- Validate file size client-side before upload starts; also enforce server-side or in presigned URL policy
- S3 multipart upload natively handles chunking and resume for large files
- Show upload progress for any upload that may take >2s — XHR has native `onprogress` events
- Next.js default body limit is 4MB; increase via `config.api.bodyParser.sizeLimit` for larger payloads
