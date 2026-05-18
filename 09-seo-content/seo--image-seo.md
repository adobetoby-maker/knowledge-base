# SEO: Image SEO

## What This Solves

Images are indexed separately by Google and can drive significant traffic via Google Images. They also impact Core Web Vitals (LCP, CLS) which affect ranking. Poorly handled images are one of the most common technical SEO problems — oversized files, missing alt text, and layout shift.

## Alt Text Rules

Alt text describes the image for screen readers AND for Google's image index.

```tsx
// BAD: empty, keyword-stuffed, or redundant
<Image alt="" />
<Image alt="auto repair auto mechanic car fix oil change tire rotation Twin Falls Idaho" />
<Image alt="Image of mechanic working on car" />

// GOOD: descriptive, natural, includes topic keyword once
<Image alt="Mechanic replacing brake pads on a 2019 Honda Civic at JR's Auto Repair" />
<Image alt="Interior of Twin Falls auto repair shop with three service bays" />

// For decorative images (backgrounds, icons): empty alt IS correct
<Image alt="" aria-hidden="true" />
```

Rules:
- Describe what's actually in the image
- Include the primary keyword naturally if it fits — don't force it
- Under 125 characters
- No "image of" or "photo of" prefix — Google already knows it's an image
- Decorative images: `alt=""` (empty string, not missing attribute)

## Next.js Image Optimization

```tsx
import Image from 'next/image'

// Always specify sizes for responsive images
<Image
  src="/images/shop-exterior.jpg"
  alt="JR's Auto Repair shop exterior on Main Ave E, Twin Falls"
  width={800}
  height={600}
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 600px"
  priority={isAboveFold}  // Add for LCP images
/>
```

`priority` prop disables lazy loading and adds `<link rel="preload">` — use only for the largest image above the fold.

## File Naming

Google crawls image file names:
```
BAD:  IMG_2847.jpg, image001.jpg
GOOD: jrs-auto-repair-twin-falls-shop-exterior.jpg
GOOD: brake-pad-replacement-honda-civic.jpg
GOOD: mechanic-checking-engine-oil-level.jpg
```

Use hyphens, not underscores. Include the main topic keyword.

## Format Choice

| Format | Use Case |
|--------|----------|
| WebP | Photographs, complex images — best compression |
| AVIF | Even better compression, less browser support |
| SVG | Icons, logos, simple graphics — scales perfectly |
| PNG | Screenshots, images with transparency |
| JPEG | Legacy fallback only — prefer WebP |

Next.js automatically serves WebP when `next/image` is used.

## Image Sitemap

Images not referenced in `<img>` tags (background CSS, dynamically loaded) won't be crawled. Add them to a sitemap:

```xml
<!-- public/sitemap-images.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">
  <url>
    <loc>https://jrsautorepair.com/services/brakes</loc>
    <image:image>
      <image:loc>https://jrsautorepair.com/images/brake-service.jpg</image:loc>
      <image:title>Brake Service at JR's Auto Repair Twin Falls</image:title>
      <image:caption>Our certified mechanic inspecting brake rotors</image:caption>
    </image:image>
  </url>
</urlset>
```

## CLS Prevention

Images without explicit dimensions cause layout shift (CLS penalty):
```tsx
// BAD: no dimensions = layout shift as image loads
<img src="/photo.jpg" alt="..." />

// GOOD: explicit dimensions prevent CLS
<Image
  src="/photo.jpg"
  alt="..."
  width={800}
  height={600}
/>

// GOOD: fill mode with aspect-ratio container
<div className="relative aspect-video">
  <Image src="/photo.jpg" alt="..." fill className="object-cover" />
</div>
```

## Structured Data for Images

For product/service images, add `ImageObject` schema:
```ts
{
  '@type': 'ImageObject',
  url: 'https://example.com/image.jpg',
  width: '800',
  height: '600',
  caption: 'Description of the image',
}
```

For `LocalBusiness`, include a `photo` or `image` property pointing to your best shop/service photos.

## Responsive Images in Static Content

For images in `lib/articles.ts` content:
- Never embed full-resolution image URLs
- Use Next.js Image component in rendering components, not in the content strings
- Reference images by path, render with `<Image>` component that applies `sizes` and lazy loading
