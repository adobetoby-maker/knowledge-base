# Skill: Image Processing (Sharp / Cloudflare Images)

## Overview

Resize, crop, compress, convert, and watermark images server-side. Two approaches: on-demand (transform at serve time) via Cloudflare Images or imgproxy; on-upload via Sharp in a Node.js route. On-demand is better for images that need multiple sizes; on-upload is better when you need a fixed set of sizes immediately.

## Sharp (On-Upload Processing)

```bash
npm install sharp
npm install @types/sharp
```

```ts
import sharp from 'sharp'
import { writeFile } from 'fs/promises'

async function processUploadedImage(
  inputBuffer: Buffer,
  outputPath: string,
): Promise<{ width: number; height: number; size: number }> {
  const image = sharp(inputBuffer)
  const metadata = await image.metadata()

  await image
    .resize({
      width: 1920,
      height: 1080,
      fit: 'inside',  // Maintain aspect ratio, don't enlarge
      withoutEnlargement: true,
    })
    .webp({ quality: 82 })
    .toFile(outputPath)

  const outputMetadata = await sharp(outputPath).metadata()
  return {
    width: outputMetadata.width!,
    height: outputMetadata.height!,
    size: outputMetadata.size ?? 0,
  }
}
```

## Multiple Sizes (Thumbnail Generation)

```ts
const SIZES = {
  thumb:   { width: 150, height: 150 },
  medium:  { width: 600, height: 400 },
  large:   { width: 1200, height: 800 },
}

async function generateImageSizes(inputBuffer: Buffer): Promise<Record<string, Buffer>> {
  const results: Record<string, Buffer> = {}

  await Promise.all(
    Object.entries(SIZES).map(async ([name, size]) => {
      results[name] = await sharp(inputBuffer)
        .resize(size.width, size.height, {
          fit: name === 'thumb' ? 'cover' : 'inside',  // Thumb crops, others fit
          position: 'center',
        })
        .webp({ quality: 80 })
        .toBuffer()
    })
  )

  return results
}
```

## Cloudflare Images (On-Demand Transformations)

Store the original, transform on the fly via URL parameters — no separate size variants needed:

```ts
// Upload to Cloudflare Images
async function uploadToCloudflareImages(file: File): Promise<string> {
  const formData = new FormData()
  formData.append('file', file)
  formData.append('requireSignedURLs', 'false')

  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/images/v1`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${CF_IMAGES_TOKEN}` },
      body: formData,
    }
  )
  const data = await res.json()
  return data.result.id  // Store this ID in your DB
}

// Generate variant URLs (no extra API calls)
function getImageUrl(imageId: string, variant: 'thumb' | 'medium' | 'public'): string {
  return `https://imagedelivery.net/${CF_ACCOUNT_HASH}/${imageId}/${variant}`
}
```

Variants are configured in the Cloudflare dashboard: resize, crop, format, quality.

## Image Validation

```ts
async function validateImage(buffer: Buffer): Promise<void> {
  const metadata = await sharp(buffer).metadata()

  const MAX_DIMENSION = 8000
  const MAX_SIZE_BYTES = 10 * 1024 * 1024  // 10MB

  if (!['jpeg', 'jpg', 'png', 'webp', 'gif'].includes(metadata.format ?? '')) {
    throw new Error('Unsupported image format')
  }
  if ((metadata.width ?? 0) > MAX_DIMENSION || (metadata.height ?? 0) > MAX_DIMENSION) {
    throw new Error('Image dimensions too large')
  }
  if (buffer.length > MAX_SIZE_BYTES) {
    throw new Error('Image file too large (max 10MB)')
  }
}
```

## EXIF Stripping (Privacy)

```ts
// Strip EXIF data (GPS location, camera info) — required for user privacy
const stripped = await sharp(buffer)
  .withMetadata({ exif: {} })  // Empty exif = stripped
  .toBuffer()
```

Always strip EXIF before storing user-uploaded images — photos from smartphones contain GPS coordinates.

## Key Rules

- Sharp is CPU-intensive — run image processing in a queue (Bull/background worker), not inline in the request handler.
- `webp` at quality 82 is typically smaller than JPEG at 90 with equal visual quality.
- Never enlarge images (`withoutEnlargement: true`) — upscaling produces blurry results.
- Strip EXIF metadata from all user-uploaded images before storage — it can contain GPS coordinates.
- Store original + process on demand (Cloudflare Images) rather than pre-generating variants for unknown future sizes.
