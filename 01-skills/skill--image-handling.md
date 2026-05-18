# Skill: image-handling

**Trigger:** Working with images in web projects — upload, optimization, display, storage, or generation.
**Returns:** Next.js Image, Supabase Storage, Cloudflare R2, and ComfyUI generation patterns.

## Next.js Image Component

Always use `next/image` for images in Next.js projects. Raw `<img>` loses optimization, lazy loading, and CLS prevention.

```typescript
import Image from 'next/image'

// Fixed dimensions (product photos, avatars)
<Image
  src="/images/mechanic.jpg"
  alt="Mechanic working on car engine at Jr's Auto Repair"
  width={800}
  height={600}
  priority={isAboveFold}  // add for LCP images; remove for below-fold
/>

// Fill container (hero images, backgrounds)
<div className="relative h-64 w-full">
  <Image
    src="/images/hero.jpg"
    alt="Mountain climbing route"
    fill
    className="object-cover"
    sizes="100vw"
  />
</div>

// Responsive with sizes hint
<Image
  src={article.image}
  alt={article.title}
  width={1200}
  height={630}
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
/>
```

**`sizes` matters for performance:** Tell the browser what size the image will render at different breakpoints. This drives which srcset variant gets downloaded.

## Remote Image Domains

Must be configured in `next.config.js`:
```javascript
module.exports = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '*.supabase.co' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
      { protocol: 'https', hostname: 'upload.wikimedia.org' },
    ]
  }
}
```

Missing remote pattern → 400 error in production (not always in dev).

## Supabase Storage Upload

```typescript
// lib/storage.ts
import { createServerClient } from '@supabase/ssr'

export async function uploadImage(
  file: File,
  bucket: string,
  path: string
): Promise<string> {
  const supabase = createServerClient(/* ... */)
  
  const { error } = await supabase.storage
    .from(bucket)
    .upload(path, file, {
      cacheControl: '3600',
      upsert: false,
    })
  
  if (error) throw new Error(`Upload failed: ${error.message}`)
  
  const { data } = supabase.storage.from(bucket).getPublicUrl(path)
  return data.publicUrl
}

// Usage in route handler:
const formData = await request.formData()
const file = formData.get('image') as File
const path = `user-${userId}/${Date.now()}-${file.name}`
const url = await uploadImage(file, 'profile-images', path)
```

## File Validation Before Upload

```typescript
const MAX_SIZE = 5 * 1024 * 1024  // 5MB
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp']

function validateImage(file: File): string | null {
  if (file.size > MAX_SIZE) return 'Image must be under 5MB'
  if (!ALLOWED_TYPES.includes(file.type)) return 'Only JPEG, PNG, and WebP are accepted'
  return null
}
```

## Cloudflare R2 — Workers Apps

```typescript
// In a Cloudflare Worker
export async function uploadToR2(
  key: string,
  data: ArrayBuffer,
  contentType: string,
  env: Env
) {
  await env.R2.put(key, data, {
    httpMetadata: { contentType }
  })
  
  // Return CDN URL (requires public R2 bucket or custom domain)
  return `https://assets.yourdomain.com/${key}`
}
```

## ComfyUI Image Generation

Via the manage-worker-bee API proxy:

```typescript
const response = await fetch('https://manage.worker-bee.app/api/image-gen', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': process.env.MANAGE_API_KEY,
  },
  body: JSON.stringify({
    prompt: 'professional automotive repair shop, clean bright lighting, photo realistic',
    width: 1024,
    height: 768,
    steps: 20,
    checkpoint: 'realistic_vision'  // optional
  })
})

const { image, filename } = await response.json()
// image is "data:image/png;base64,..."
```

## Alt Text Standards

Alt text is required for accessibility AND SEO:
- Descriptive: describes what's in the image
- Functional: if the image is a link/button, describe the destination/action
- Keyword-natural: include primary keyword if it fits naturally; never keyword-stuff alt text
- Empty string `alt=""` for purely decorative images (not empty missing — actually `alt=""`)

```typescript
// Good
alt="Mechanic inspecting brake pads on a 2019 Toyota Camry"

// Bad — generic
alt="car repair"

// Bad — keyword stuffed  
alt="auto repair Twin Falls Idaho mechanic car repair service"

// Correct — decorative
alt=""
```

## Image Optimization Script

For batch operations on existing images, use Sharp (Node.js):

```typescript
import sharp from 'sharp'

await sharp(inputPath)
  .resize(1200, 630, { fit: 'cover' })
  .webp({ quality: 85 })
  .toFile(outputPath)
```
