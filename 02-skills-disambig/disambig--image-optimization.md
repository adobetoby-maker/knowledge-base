# Disambiguation: Image Optimization Choice

## Next.js Image Component vs Plain `<img>`

Always use `next/image` for every image in Next.js projects. The only exception is inside `ImageResponse` (OG image generation) where JSX renders to a canvas — use `<img>` there.

```typescript
// CORRECT for all app pages:
import Image from 'next/image'
<Image src="/hero.jpg" alt="..." width={1200} height={630} />

// CORRECT for ImageResponse in opengraph-image.tsx:
// eslint-disable-next-line @next/next/no-img-element
<img src="https://example.com/logo.png" width={60} height={60} alt="" />
```

## Priority: Only One Image Per Page

Mark ONLY the above-the-fold LCP (Largest Contentful Paint) image as `priority`. Adding priority to multiple images defeats the purpose:

```typescript
// Hero image — LCP element → priority
<Image src="/hero-auto-shop.jpg" alt="..." priority width={1200} height={630} />

// Other images — lazy loaded by default
<Image src="/shop-interior.jpg" alt="..." width={800} height={500} />
// DO NOT add priority here
```

If your LCP image is inside a Carousel or conditional render, it might not get the `priority` treatment it needs. Move critical images out of `{condition && <Image />}` wrappers if possible.

## Fill vs Fixed Dimensions

```typescript
// FIXED DIMENSIONS — when you know the exact size:
<Image src="..." alt="..." width={400} height={300} />

// FILL — when the image fills its container:
<div className="relative h-64 w-full">
  <Image src="..." alt="..." fill className="object-cover" />
</div>

// RESPONSIVE — fill a container that changes size:
<div className="relative aspect-video w-full">
  <Image src="..." alt="..." fill className="object-cover" />
</div>
```

`fill` requires the parent to have `position: relative` (or `absolute`) and an explicit size. Without this, the image is invisible.

## Remote Images: Configure Domains

Next.js blocks remote images by default. Add allowed hosts to `next.config.ts`:

```typescript
// next.config.ts
const config: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
      },
      {
        protocol: 'https',
        hostname: '*.supabase.co',   // wildcard for your project ID
      },
      {
        protocol: 'https',
        hostname: 'upload.wikimedia.org',
      },
    ],
  },
}
```

Pattern: `*.supabase.co` covers `your-project-id.supabase.co`.

## Supabase Storage Images

```typescript
// Get public URL from Supabase storage
const { data } = supabase.storage.from('images').getPublicUrl('photo.jpg')
// Returns: https://YOUR_PROJECT_ID.supabase.co/storage/v1/object/public/images/photo.jpg

// Use with next/image (domain must be in remotePatterns):
<Image
  src={data.publicUrl}
  alt="..."
  width={400}
  height={300}
/>
```

## Sizes Attribute for Responsive Images

The `sizes` prop tells the browser which image variant to download at each viewport:

```typescript
// Full-width hero:
<Image src="..." alt="..." fill sizes="100vw" />

// Two-column grid (50% wide on desktop, full-width on mobile):
<Image src="..." alt="..." fill sizes="(max-width: 768px) 100vw, 50vw" />

// Fixed sidebar thumbnail:
<Image src="..." alt="..." width={200} height={200} sizes="200px" />
```

Without `sizes`, Next.js generates all variants but the browser downloads the largest one regardless of viewport.

## Which Format to Use

| Format | When |
|---|---|
| Next.js automatic (AVIF/WebP) | Always — `next/image` handles format selection |
| SVG | Icons, logos, diagrams (not via `next/image` — use `<img>` or inline) |
| PNG | Screenshots, UI with transparency |
| JPG | Photos (Next.js converts to WebP/AVIF automatically) |
| GIF | Avoid — use `<video autoplay muted loop>` for animation |

## CLS Prevention

Always set `width` and `height` (or `fill` with a sized container). Without dimensions, the browser doesn't know the aspect ratio and the image causes layout shift (CLS):

```typescript
// CAUSES CLS — no dimensions:
<Image src="..." alt="..." />  // TypeScript error too

// PREVENTS CLS:
<Image src="..." alt="..." width={800} height={600} />
```
