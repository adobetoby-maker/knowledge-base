# Generating Thumbnails for Uploaded Media

## Why a Batch Job Instead of On-Upload

Synchronous thumbnail generation during upload blocks the upload response, increases upload latency by 200–2000ms, and fails atomically — if thumbnail generation errors, the upload fails too. A batch job decouples them: the file is stored immediately, thumbnails are generated asynchronously, and failures can be retried without affecting the upload record.

The only reason to generate thumbnails synchronously is if the UI blocks on thumbnail availability immediately after upload. Most UIs can show a placeholder while thumbnails are pending.

## Sharp for Image Resizing

Sharp is the standard Node.js image processing library. It uses libvips under the hood, which is significantly faster than ImageMagick or Jimp for resize operations.

```js
import sharp from 'sharp';

const sizes = [
  { name: 'thumb', width: 150, height: 150 },
  { name: 'medium', width: 400, height: 400 },
  { name: 'large', width: 800, height: 800 },
];

for (const { name, width, height } of sizes) {
  await sharp(sourceBuffer)
    .resize(width, height, { fit: 'cover', position: 'attention' }) // smart crop
    .webp({ quality: 80 })
    .toFile(`${outputPath}/${assetId}/${name}.webp`);
}
```

Use `fit: 'cover'` for thumbnails (crops to fill the box) and `fit: 'inside'` for content previews (letterbox preserving aspect ratio). The `position: 'attention'` option uses libvips' smart entropy detection to crop on the most visually interesting part.

## Multiple Size Variants

Maintain three standard sizes:
- **thumb (150px):** Grid views, search results, hover cards
- **medium (400px):** Single-column feeds, inline previews
- **large (800px):** Full-width content sections, detail pages

Store the original file unchanged. Never overwrite the source with a processed variant. Original preservation is non-negotiable for any use case where quality matters (photos, documents, designs).

## WebP Conversion

WebP consistently produces 25–40% smaller files than JPEG at equivalent quality. Generate WebP by default. If you need JPEG fallback (email clients, older apps), generate both but serve WebP as the primary format.

Set quality 80 for photographic content, 90 for graphic/UI content (WebP compression handles graphics differently than JPEG).

## Skipping Already-Processed Files

Track processing status per asset:

```sql
ALTER TABLE media_assets ADD COLUMN thumbnail_status TEXT DEFAULT 'pending';
-- values: 'pending', 'processing', 'complete', 'failed'
ALTER TABLE media_assets ADD COLUMN thumbnail_generated_at TIMESTAMPTZ;
```

The batch job queries: `WHERE thumbnail_status IN ('pending', 'failed')`.

This is the idempotency gate — running the job twice doesn't regenerate thumbnails for completed assets. On retry (for failed assets), it processes only the ones that actually need work.

## Updating DB with Variant URLs

After generating all size variants, update the DB in a single write:

```sql
UPDATE media_assets SET
  thumb_url = $1,
  medium_url = $2,
  large_url = $3,
  thumbnail_status = 'complete',
  thumbnail_generated_at = NOW()
WHERE id = $4;
```

Store the full URL (not just the path) so the frontend can use it without constructing paths. If your CDN URL changes, a migration is easier than fixing URL construction logic scattered across the codebase.

## Error Handling

If Sharp throws (corrupt source file, unsupported format), set `thumbnail_status = 'failed'` with an error message. Permanently failed assets (after 3 attempts) should be flagged for manual review rather than retried indefinitely — corrupt files will always fail.

Log every failure with `asset_id` and error message. A cluster of failures from the same time window often indicates a storage read issue, not corrupt files.

## Key Rules

- Generate thumbnails asynchronously; never block the upload response on thumbnail creation.
- Track `thumbnail_status` per asset to gate idempotent re-runs.
- Use `fit: 'cover'` with `position: 'attention'` for thumbnail crops — smart cropping beats center-crop for non-portrait subjects.
- Always preserve the original file; never overwrite it with a processed variant.
- Store full URLs in DB, not relative paths — URL construction logic belongs at write time, not read time.
- Permanently flag assets that fail after 3 attempts rather than retrying forever.
