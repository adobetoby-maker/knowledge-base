# Batch: Storage Usage Report

## What This Covers

Computing storage usage per tenant or user: listing objects in S3 (or compatible storage) with per-user prefix scoping, summing sizes, comparing against quota limits, sending warning emails at 80% and hard-limit notifications at 100%, and archiving old files to cheaper storage tiers.

## Why Per-User Prefix Scoping Matters

Store files under a deterministic per-user/per-tenant prefix from day one: `uploads/{userId}/` or `tenants/{tenantId}/files/`. This enables efficient storage enumeration without querying a file metadata table — `ListObjectsV2` with a prefix is O(objects in that prefix), not O(all objects).

If files are stored flat without namespacing, you must cross-reference a database table to compute per-user totals, which is slow and can drift out of sync with the actual storage.

## Listing and Summing with `ListObjectsV2`

S3 returns up to 1000 objects per page. Use pagination until `IsTruncated` is false.

```ts
import { S3Client, ListObjectsV2Command } from '@aws-sdk/client-s3'

const s3 = new S3Client({ region: process.env.AWS_REGION })

async function getUserStorageBytes(userId: string): Promise<number> {
  let totalBytes = 0
  let continuationToken: string | undefined
  
  do {
    const response = await s3.send(new ListObjectsV2Command({
      Bucket: process.env.S3_BUCKET!,
      Prefix: `uploads/${userId}/`,
      ContinuationToken: continuationToken,
    }))
    
    for (const obj of response.Contents ?? []) {
      totalBytes += obj.Size ?? 0
    }
    
    continuationToken = response.IsTruncated ? response.NextContinuationToken : undefined
  } while (continuationToken)
  
  return totalBytes
}
```

For Supabase Storage, use the `storage-js` admin client or query the `objects` table directly:

```sql
SELECT owner, sum(metadata->>'size')::bigint AS total_bytes
FROM storage.objects
WHERE bucket_id = 'uploads'
GROUP BY owner;
```

## Nightly Batch: All Users

Run per-user enumeration in parallel but rate-limit to avoid S3 throttling (AWS default: 3,500 PUT/1,000 GET requests per second per prefix):

```ts
async function computeAllStorageUsage() {
  const users = await db.query('SELECT id, email, storage_quota_bytes FROM users')
  
  const results = await Promise.allSettled(
    users.rows.map(user =>
      limit(() => processUserStorage(user))  // limit concurrency with p-limit
    )
  )
  
  const errors = results.filter(r => r.status === 'rejected')
  if (errors.length) {
    console.error(`${errors.length} users failed storage calculation`)
  }
}

async function processUserStorage(user: User) {
  const usedBytes = await getUserStorageBytes(user.id)
  const quotaBytes = user.storage_quota_bytes
  
  // Update the storage_usage table (single source of truth for UI)
  await db.query(`
    INSERT INTO storage_usage (user_id, used_bytes, computed_at)
    VALUES ($1, $2, now())
    ON CONFLICT (user_id) DO UPDATE SET used_bytes = $2, computed_at = now()
  `, [user.id, usedBytes])
  
  // Check thresholds
  const pct = usedBytes / quotaBytes
  
  if (pct >= 1.0) {
    await sendStorageAlert(user, 'hard_limit', usedBytes, quotaBytes)
  } else if (pct >= 0.8) {
    await sendStorageAlert(user, 'warning', usedBytes, quotaBytes)
  }
}
```

Use `p-limit` with concurrency of 10–20. Avoid `Promise.all` over thousands of users — it opens all requests simultaneously and overwhelms the S3 rate limit.

## Warning and Hard Limit Notifications

Prevent notification spam: only send one warning email per threshold breach per 7-day window.

```ts
async function sendStorageAlert(user: User, type: 'warning' | 'hard_limit', used: number, quota: number) {
  const cooldownKey = `storage_alert:${user.id}:${type}`
  const alreadySent = await redis.get(cooldownKey)
  if (alreadySent) return
  
  const pct = Math.round((used / quota) * 100)
  const usedGb = (used / 1024 ** 3).toFixed(2)
  const quotaGb = (quota / 1024 ** 3).toFixed(2)
  
  await email.send({
    to: user.email,
    subject: type === 'hard_limit'
      ? `Storage limit reached (${usedGb} GB / ${quotaGb} GB)`
      : `Storage at ${pct}% — ${usedGb} GB used of ${quotaGb} GB`,
    template: type === 'hard_limit' ? 'storage-hard-limit' : 'storage-warning',
    data: { pct, usedGb, quotaGb, upgradeUrl: 'https://app.example.com/billing' },
  })
  
  // Don't send the same alert again for 7 days
  await redis.setex(cooldownKey, 7 * 24 * 3600, '1')
}
```

## Archiving to Cheaper Storage

Files not accessed in 90 days can move to S3 Glacier Instant Retrieval (or similar), reducing cost by ~75%.

Option A: S3 Lifecycle Policy (fully automatic, no code):
```json
{
  "Rules": [{
    "Id": "ArchiveOldUploads",
    "Status": "Enabled",
    "Filter": { "Prefix": "uploads/" },
    "Transitions": [{
      "Days": 90,
      "StorageClass": "GLACIER_IR"
    }]
  }]
}
```

Option B: Script-based archiving (use when you need finer control — e.g., only archive files owned by paid users, exclude recently accessed files tracked in your DB):

```ts
const oldObjects = await db.query(`
  SELECT s3_key FROM file_metadata
  WHERE last_accessed_at < now() - interval '90 days'
    AND storage_class = 'STANDARD'
  LIMIT 1000
`)

for (const obj of oldObjects.rows) {
  await s3.send(new CopyObjectCommand({
    Bucket: BUCKET, CopySource: `${BUCKET}/${obj.s3_key}`, Key: obj.s3_key,
    StorageClass: 'GLACIER_IR',
  }))
  await db.query('UPDATE file_metadata SET storage_class = $1 WHERE s3_key = $2', ['GLACIER_IR', obj.s3_key])
}
```

## Key Rules

- Namespace files by user/tenant prefix from day one to enable efficient enumeration
- Paginate `ListObjectsV2` — a single call returns at most 1000 objects
- Limit concurrency when processing many users; do not open thousands of S3 requests simultaneously
- Debounce alert emails with a 7-day cooldown per user per threshold to prevent spam
- Prefer S3 Lifecycle Policies for archiving over custom scripts when rules are simple
- Store computed `used_bytes` in a DB table so the UI can show usage without real-time S3 calls
- Run this job at off-peak hours — it's read-heavy but generates significant S3 API call volume
