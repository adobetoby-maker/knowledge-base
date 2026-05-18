# Failure Patterns: next/image Errors

## "hostname not configured under images"

Error: `Error: Invalid src prop on next/image, hostname "images.unsplash.com" is not configured under images in your next.config.js`

Fix: Add the hostname to `remotePatterns` in `next.config.ts`:
```typescript
images: {
  remotePatterns: [
    { protocol: 'https', hostname: 'images.unsplash.com' },
    { protocol: 'https', hostname: '*.supabase.co' },  // wildcard for project ID
    { protocol: 'https', hostname: 'upload.wikimedia.org' },
  ],
}
```

If the hostname includes a port: `{ hostname: 'localhost', port: '3000' }`.

## "fill requires parent to have position"

Error: Image with `fill` prop renders invisible or throws a warning about missing parent positioning.

Fix: The parent container MUST have `position: relative` (or `absolute`/`fixed`) and an explicit size:
```typescript
// WRONG — parent has no positioning or size:
<div className="w-full">
  <Image fill src="..." alt="..." />
</div>

// CORRECT:
<div className="relative w-full h-64">
  <Image fill src="..." alt="..." className="object-cover" />
</div>

// CORRECT with aspect ratio:
<div className="relative aspect-video w-full">
  <Image fill src="..." alt="..." className="object-cover" />
</div>
```

## LCP Image Not Loading Fast Enough

The page's LCP image is loading slowly — CWV score is bad.

Cause: Missing `priority` prop on the hero/LCP image.

Fix:
```typescript
// First/hero image ONLY — mark as priority:
<Image src="/hero.jpg" alt="..." width={1200} height={630} priority />
```

Do NOT add `priority` to multiple images — it defeats the purpose by requesting them all eagerly.

Also verify the image is in the `public/` directory (not behind dynamic import) and isn't inside a `{condition && ...}` that might hide it on initial render.

## "alt" prop missing

Warning: `Image is missing required "alt" property`

Fix: Always provide alt text. For decorative images, use empty string:
```typescript
<Image alt="" aria-hidden="true" src="..." ... />    // decorative
<Image alt="Mechanic changing oil" src="..." ... />  // meaningful
```

## Blurry / Low Quality Images

Symptom: Images appear blurry or pixelated.

Cause 1: Image source is too small for the container. Next.js can't upscale past the source resolution.

Cause 2: `quality` prop is too low (default is 75, acceptable range is 75-90 for photos):
```typescript
// Bump quality for hero images where quality matters:
<Image src="..." alt="..." quality={85} ... />
```

Cause 3: No `sizes` prop on responsive images — browser selects a small variant:
```typescript
// Tell the browser the image will be full-width on mobile, 50% on desktop:
<Image
  src="..."
  alt="..."
  fill
  sizes="(max-width: 768px) 100vw, 50vw"
/>
```

## CLS from Missing Dimensions

Symptom: Page content jumps when image loads — high CLS score.

Cause: No `width`/`height` provided, so the browser doesn't reserve space.

Fix: Always provide dimensions or use `fill` with a sized container:
```typescript
// With dimensions — browser reserves space:
<Image src="..." alt="..." width={800} height={600} />

// With fill — parent reserves space:
<div className="relative h-48 w-full">
  <Image src="..." alt="..." fill className="object-cover" />
</div>
```

## SVG Files Don't Work with next/image

`next/image` doesn't optimize SVGs (no format conversion, no resizing).

Fix: Use `<img>` for SVGs, or inline the SVG:
```typescript
// For SVG icons:
import Logo from '@/public/logo.svg'  // requires svg-as-component setup
// or
<img src="/logo.svg" alt="Company logo" width={120} height={40} />

// For photos and raster images:
<Image src="/photo.jpg" alt="..." width={400} height={300} />
```

## Images in opengraph-image.tsx Use `<img>` Not `next/image`

`ImageResponse` renders to a canvas — the `next/image` component's optimization pipeline doesn't apply there.

```typescript
// opengraph-image.tsx — use plain img:
// eslint-disable-next-line @next/next/no-img-element
<img src="https://example.com/logo.png" width={60} height={60} alt="" />
```

Images in `ImageResponse` MUST be absolute URLs (not relative paths like `/logo.png`).
