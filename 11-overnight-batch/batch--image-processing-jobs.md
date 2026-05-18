# Overnight Image Processing Jobs

## Use Cases

- Generating Open Graph images for all articles
- Resizing/converting uploaded images to multiple sizes
- Generating AI illustrations for blog posts
- Downloading and optimizing stock photos for destinations
- Creating thumbnails for product galleries

## OG Image Generation via ComfyUI

Using the manage-worker-bee ComfyUI API:

```typescript
// scripts/generate-og-images.ts
import { writeFile } from 'fs/promises'
import { existsSync } from 'fs'
import { articles } from '../lib/articles'

const COMFY_API = 'https://manage.worker-bee.app/api/image-gen'
const API_KEY = '9fd6a40a79137d7fdb4ea7dc97d7c40478af2fae339dc8b25cc4595bd8dd1747'
const OUTPUT_DIR = './public/og'

async function generateOGImage(title: string, slug: string): Promise<boolean> {
  const outputPath = `${OUTPUT_DIR}/${slug}.png`
  
  if (existsSync(outputPath)) {
    console.log(`SKIP (exists): ${slug}`)
    return true
  }

  try {
    const response = await fetch(COMFY_API, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': API_KEY,
      },
      body: JSON.stringify({
        prompt: `Professional automotive service illustration for blog post: "${title}". Clean, modern style, no text.`,
        width: 1200,
        height: 630,
        steps: 20,
      }),
    })

    if (!response.ok) {
      console.error(`API error for ${slug}: ${response.status}`)
      return false
    }

    const { image } = await response.json()
    if (!image) return false

    // image is base64 data URL: "data:image/png;base64,..."
    const base64 = image.replace('data:image/png;base64,', '')
    const buffer = Buffer.from(base64, 'base64')
    await writeFile(outputPath, buffer)
    
    console.log(`Generated: ${slug}.png`)
    return true
  } catch (err) {
    console.error(`Failed: ${slug} — ${(err as Error).message}`)
    return false
  }
}

async function runBatch() {
  let success = 0, failed = 0

  for (const article of articles) {
    const ok = await generateOGImage(article.title, article.slug)
    if (ok) success++ else failed++
    
    // Rate limit — ComfyUI needs time between generations
    await new Promise(r => setTimeout(r, 3000))
  }

  console.log(`Done: ${success} generated, ${failed} failed`)
}

runBatch().catch(console.error)
```

## Programmatic OG Images via next/og

A faster alternative — generate OG images at request time using `ImageResponse`:

```typescript
// app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og'
import { articles } from '@/lib/articles'

export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function OGImage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const article = articles.find(a => a.slug === slug)

  return new ImageResponse(
    (
      <div style={{
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'flex-end',
        padding: '60px',
        background: 'linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)',
        width: '100%',
        height: '100%',
      }}>
        <div style={{ color: '#e94560', fontSize: '18px', fontWeight: 600, marginBottom: '16px' }}>
          Jr.'s Auto Repair Blog
        </div>
        <div style={{ color: 'white', fontSize: '48px', fontWeight: 700, lineHeight: 1.2 }}>
          {article?.title ?? 'Article'}
        </div>
        <div style={{ color: 'rgba(255,255,255,0.7)', fontSize: '24px', marginTop: '20px' }}>
          Twin Falls, ID • (208) 595-2101
        </div>
      </div>
    ),
    { ...size }
  )
}
```

This approach is preferred over pre-generating images — no build step, no storage, always up to date.

## Stock Photo Download Job

For climb sites, download Wikimedia/Unsplash photos:

```typescript
// scripts/download-photos.ts
import { writeFile } from 'fs/promises'
import { createWriteStream } from 'fs'
import { pipeline } from 'stream/promises'

const PHOTOS = [
  {
    slug: 'frade-overview',
    url: 'https://commons.wikimedia.org/wiki/Special:FilePath/Frade-rock-face.jpg',
    alt: 'Frade rock climbing area overview',
  },
  // ...
]

async function downloadPhoto(url: string, outputPath: string): Promise<boolean> {
  try {
    const response = await fetch(url, {
      headers: { 'User-Agent': 'ClimbBrasil/1.0 (climbbrasil.com)' }
    })
    
    if (!response.ok) return false
    
    const stream = createWriteStream(outputPath)
    await pipeline(response.body!, stream)
    return true
  } catch {
    return false
  }
}
```

## Image Optimization Script

After downloading photos, optimize with sharp:

```typescript
import sharp from 'sharp'

async function optimizeImage(inputPath: string, outputPath: string) {
  await sharp(inputPath)
    .resize(1200, 800, { fit: 'cover', position: 'center' })
    .webp({ quality: 85 })
    .toFile(outputPath)
}

// Process all downloaded photos
for (const photo of downloadedPhotos) {
  await optimizeImage(photo.original, photo.optimized)
}
```

## Job Monitoring

```bash
# Run in background and monitor
nohup npx ts-node scripts/generate-og-images.ts > /tmp/og-gen.log 2>&1 &

# Monitor
tail -f /tmp/og-gen.log

# Check progress
grep -c "Generated" /tmp/og-gen.log
grep -c "SKIP" /tmp/og-gen.log
grep -c "Failed" /tmp/og-gen.log
```
