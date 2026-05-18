# Plugin: Sharp

## What It Is

Sharp is a high-performance Node.js image processing library. Used for: resize, compress, format convert (WebP/AVIF), crop, thumbnail generation, metadata extraction. Runs on native libvips. Used server-side only (Node.js/Route Handlers) — not available in Cloudflare Workers.

## Installation

```bash
npm install sharp
npm install --save-dev @types/sharp
```

## Core Operations

### Resize and Convert to WebP

```ts
import sharp from 'sharp'
import { writeFile } from 'fs/promises'

async function processUpload(buffer: Buffer, filename: string) {
  const optimized = await sharp(buffer)
    .resize(1200, 800, {
      fit: 'inside',        // Maintain aspect ratio, fit within bounds
      withoutEnlargement: true,  // Don't upscale small images
    })
    .webp({ quality: 85 })
    .toBuffer()

  return optimized
}
```

### Generate Multiple Sizes

```ts
async function generateSizes(buffer: Buffer) {
  const sizes = [
    { name: 'thumb', width: 150, height: 150 },
    { name: 'medium', width: 400, height: 400 },
    { name: 'large', width: 1200, height: 900 },
  ]

  const results = await Promise.all(
    sizes.map(async ({ name, width, height }) => {
      const data = await sharp(buffer)
        .resize(width, height, { fit: 'cover', position: 'centre' })
        .webp({ quality: 85 })
        .toBuffer()
      return { name, data }
    })
  )

  return results
}
```

`fit: 'cover'` crops to fill the target dimensions. `fit: 'inside'` preserves full image within bounds. `fit: 'contain'` adds letterboxing.

### Profile Photo Crop

```ts
async function processAvatar(buffer: Buffer): Promise<Buffer> {
  const metadata = await sharp(buffer).metadata()

  // Square crop from center
  const size = Math.min(metadata.width!, metadata.height!)

  return sharp(buffer)
    .extract({
      left: Math.floor((metadata.width! - size) / 2),
      top: Math.floor((metadata.height! - size) / 2),
      width: size,
      height: size,
    })
    .resize(256, 256)
    .webp({ quality: 90 })
    .toBuffer()
}
```

### Upload Flow: Supabase Storage + Sharp

```ts
// app/api/upload/avatar/route.ts
import { NextRequest, NextResponse } from 'next/server'
import sharp from 'sharp'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'

export async function POST(request: NextRequest) {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const formData = await request.formData()
  const file = formData.get('file') as File
  if (!file) return NextResponse.json({ error: 'No file' }, { status: 400 })

  const buffer = Buffer.from(await file.arrayBuffer())

  // Validate it's an image
  const metadata = await sharp(buffer).metadata().catch(() => null)
  if (!metadata) return NextResponse.json({ error: 'Invalid image' }, { status: 400 })

  // Process
  const processed = await sharp(buffer)
    .resize(256, 256, { fit: 'cover' })
    .webp({ quality: 90 })
    .toBuffer()

  const path = `avatars/${user.id}.webp`
  const { error } = await supabase.storage
    .from('media')
    .upload(path, processed, {
      contentType: 'image/webp',
      upsert: true,
    })

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })

  const { data: { publicUrl } } = supabase.storage.from('media').getPublicUrl(path)
  return NextResponse.json({ url: `${publicUrl}?v=${Date.now()}` })
}
```

## Format Comparison

| Format | Use case | Quality setting |
|--------|---------|-----------------|
| WebP | General web images | `quality: 80-90` |
| AVIF | Smaller files, newer browsers | `quality: 50-65` (different scale) |
| JPEG | Photos, no transparency | `quality: 80-90` |
| PNG | Screenshots, transparency | `compressionLevel: 9` |

WebP is the safe default — ~30% smaller than JPEG at same visual quality, supported by all modern browsers.

## Metadata Extraction

```ts
const meta = await sharp(buffer).metadata()
// meta.width, meta.height, meta.format, meta.size (bytes), meta.exif
```

Check metadata before processing — reject files that aren't images before calling Sharp.

## Memory Management

Sharp uses libvips memory. For batch processing, limit concurrency:

```ts
import pLimit from 'p-limit'

const limit = pLimit(5)  // Max 5 concurrent sharp operations

await Promise.all(
  images.map((img) => limit(() => processImage(img)))
)
```

## Cloudflare Workers Alternative

Sharp doesn't run on Cloudflare Workers (no Node.js native modules). Use:
- Cloudflare Images — managed image service
- `@cf-wasm/photon` — Wasm-based image processing
- Pre-process with Sharp in a Node.js Route Handler, store result in R2
