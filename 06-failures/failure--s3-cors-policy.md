# S3/R2 CORS Configuration Errors for Browser Uploads

CORS errors on S3/R2 uploads are consistently confusing because the failure message ("has been blocked by CORS policy") appears in the browser but the fix is on the storage bucket — not in the application server. Understanding where CORS is enforced is the first step.

## What CORS Is Doing Here

When a browser makes a request to a different origin (e.g., your app on `app.example.com` uploading to `bucket.s3.amazonaws.com`), the browser first sends a preflight `OPTIONS` request asking S3 if the cross-origin upload is permitted. S3 responds with CORS headers. If those headers don't match the browser's origin and method, the browser blocks the upload before it starts.

The application server is not involved in this exchange. Configuring CORS headers on your Next.js server doesn't help.

## Required CORS Configuration on S3/R2

In the bucket CORS settings (AWS Console or Terraform), you need:

```json
[
  {
    "AllowedOrigins": ["https://app.example.com"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

Key points:
- `AllowedOrigins`: list specific origins; use `["*"]` only for public read buckets, never for write buckets
- `AllowedMethods`: include all methods your upload flow uses. Multipart uploads need `POST` and `PUT`. `HEAD` is needed for existence checks.
- `AllowedHeaders`: `["*"]` is safe here — it doesn't grant permissions, it just tells the browser which request headers are allowed in the preflight
- `ExposeHeaders`: must include `ETag` for multipart uploads to work — the browser needs to read ETag from the upload response to assemble the multipart manifest

For Cloudflare R2, the CORS config is identical in structure but set in the R2 bucket dashboard or via `wrangler.toml`.

## Why Presigned URL Uploads Don't Bypass CORS

A common misconception: "we're using presigned URLs, so CORS doesn't apply." Wrong. A presigned URL just proves the request is authorized (via signature). It says nothing about which origins can initiate the request. The browser still sends a preflight `OPTIONS` request to the bucket, and the bucket still needs the CORS config to permit the browser's origin.

Presigned URLs solve authentication; CORS config solves cross-origin browser policy. They're orthogonal.

## ExposeHeaders for ETag

The `ETag` header is returned by S3 in the response to each part of a multipart upload. The browser (or JavaScript SDK) needs to read the ETag to assemble the `CompleteMultipartUpload` request. By default, S3 doesn't expose custom response headers to browser scripts — you must list them in `ExposeHeaders`.

If ETag is missing from `ExposeHeaders`, multipart uploads will fail silently or with a cryptic "cannot read property" error after all parts have uploaded successfully. Add `"ETag"` to `ExposeHeaders` whenever you support multipart uploads.

## Testing CORS Config with curl

Before debugging in the browser, verify the CORS config responds correctly:

```bash
# Preflight check — simulates what the browser sends
curl -X OPTIONS "https://your-bucket.s3.amazonaws.com/test-key" \
  -H "Origin: https://app.example.com" \
  -H "Access-Control-Request-Method: PUT" \
  -H "Access-Control-Request-Headers: content-type" \
  -v 2>&1 | grep -i "access-control"
```

Expected response headers:
```
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, PUT, POST, DELETE, HEAD
Access-Control-Allow-Headers: *
Access-Control-Expose-Headers: ETag
```

If these headers are missing or wrong, the CORS config on the bucket is incorrect — fix it there, not in application code.

## Key Rules

- CORS errors on bucket uploads are fixed in bucket CORS config, not application server config
- Presigned URLs do not bypass CORS — they handle auth, not browser cross-origin policy
- Always include `ETag` in `ExposeHeaders` when supporting multipart uploads
- `AllowedHeaders: ["*"]` in CORS is safe — it describes allowed request headers, not permissions
- Test CORS with a manual `curl` preflight before debugging in the browser
- In production, use specific origins in `AllowedOrigins`; `["*"]` is only acceptable for truly public read buckets
