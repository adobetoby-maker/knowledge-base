# Responsive Image Patterns

## next/image Fundamentals

`next/image` handles: lazy loading, responsive sizes, WebP/AVIF conversion, blur placeholder, and layout shift prevention.

Always use it instead of `<img>` in Next.js projects.

## Basic Usage

```typescript
import Image from 'next/image'

// Fixed dimensions (for images with known size)
<Image
  src="/hero.jpg"
  alt="Workshop interior at Jr.'s Auto Repair"
  width={1200}
  height={630}
  priority  // for above-the-fold images (LCP)
/>

// Fill container (for images that should fill parent)
<div className="relative aspect-video">
  <Image
    src="/workshop.jpg"
    alt="Auto repair workshop"
    fill
    className="object-cover"
    sizes="(max-width: 768px) 100vw, 50vw"
  />
</div>
```

## The `sizes` Attribute

The `sizes` attribute tells the browser what width the image will be at different viewport widths. This controls which resolution is downloaded.

```typescript
// Full width image
<Image sizes="100vw" />

// 50% width on desktop, full on mobile
<Image sizes="(max-width: 768px) 100vw, 50vw" />

// Fixed sidebar image
<Image sizes="(max-width: 768px) 100vw, (max-width: 1200px) 33vw, 400px" />
```

Without `sizes`, Next.js assumes the image fills the viewport — it downloads unnecessarily large images on desktop for mobile-sized images.

## `priority` for LCP

The Largest Contentful Paint (LCP) image should be loaded eagerly. Use `priority` on it:

```typescript
// Above the fold — load immediately
<Image src="/hero.jpg" priority />

// Below the fold — lazy load (default)
<Image src="/services.jpg" />
```

Only one or two images per page should have `priority`. Overusing it defeats the purpose.

## Remote Images

Remote images need domain configuration:

```typescript
// next.config.js
module.exports = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
      },
      {
        protocol: 'https',
        hostname: '*.supabase.co',  // wildcard for Supabase Storage
      },
    ],
  },
}
```

## Blur Placeholder

For large images, show a blurred preview while loading:

```typescript
// Static imports get auto-generated blur placeholder
import heroImage from '@/public/hero.jpg'

<Image
  src={heroImage}
  alt="Hero"
  placeholder="blur"  // auto-generated from imported image
/>

// Remote images need a generated blurDataURL
<Image
  src={remoteUrl}
  alt="Remote image"
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD..."
  // Generate with: npx plaiceholder or similar tool
/>
```

## Supabase Storage Images

```typescript
// Get public URL from Supabase
const { data: { publicUrl } } = supabase
  .storage
  .from('avatars')
  .getPublicUrl(`${userId}/avatar.jpg`)

// Use in Image component
<Image
  src={publicUrl}
  alt="User avatar"
  width={64}
  height={64}
  className="rounded-full"
/>
```

Add Supabase hostname to `remotePatterns` in `next.config.js`.

## Gallery Pattern (Multiple Images)

```typescript
export function ImageGallery({ images }: { images: GalleryImage[] }) {
  return (
    <div className="grid grid-cols-2 gap-2 md:grid-cols-3">
      {images.map((image, index) => (
        <div key={image.src} className="relative aspect-square">
          <Image
            src={image.src}
            alt={image.alt}
            fill
            className="rounded-md object-cover"
            sizes="(max-width: 768px) 50vw, 33vw"
            priority={index < 2}  // only first 2 images load eagerly
          />
        </div>
      ))}
    </div>
  )
}
```

## Cloudflare Workers (opennextjs/cloudflare)

When deploying Next.js to Cloudflare Workers, the built-in image optimization (`/_next/image`) may not work the same way. Options:
1. Use Cloudflare Images for optimization
2. Serve images directly from R2 with proper headers
3. Disable image optimization and serve original files

```typescript
// next.config.js for Cloudflare deployment
module.exports = {
  images: {
    loader: 'custom',        // custom loader for Cloudflare
    loaderFile: './src/image-loader.ts',
  },
}
```

## Common Mistakes

- **Missing `alt` text** — required for accessibility; describe the image content
- **Missing `sizes`** — browser downloads too-large images
- **`priority` on every image** — defeats lazy loading, worse performance
- **No `width`/`height` for layout** — causes layout shift (CLS); always specify dimensions
- **Using `<img>` instead of `<Image>`** — loses all Next.js optimization benefits
