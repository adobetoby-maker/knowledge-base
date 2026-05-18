# Image Optimization Pipeline

## Why Image Size Dominates Performance

Images are typically 60–80% of page weight. A single unoptimized hero image can cost 3–5s of LCP on mobile. The browser cannot start rendering what it can't download. Every byte saved is faster paint. The three levers: format (WebP vs JPEG), dimensions (serve the size the layout actually uses), and loading strategy (defer what's below the fold).

## Format Selection: WebP with Fallback

WebP achieves 25–35% smaller file size than JPEG at equivalent visual quality. AVIF is 50% smaller than JPEG but has slower encoding and still lacks IE11/older Safari support.

Server-side rule: detect `Accept: image/webp` in the request header and serve WebP. If absent, serve JPEG.

```ts
import sharp from 'sharp';

async function optimizeImage(input: Buffer, width: number): Promise<{ webp: Buffer; jpeg: Buffer }> {
  const pipeline = sharp(input).resize(width, null, {
    withoutEnlargement: true,  // never upscale
    fit: 'inside',
  });
  const [webp, jpeg] = await Promise.all([
    pipeline.clone().webp({ quality: 80 }).toBuffer(),
    pipeline.clone().jpeg({ quality: 82, progressive: true }).toBuffer(),
  ]);
  return { webp, jpeg };
}
```

Use `progressive: true` for JPEG — progressive JPEGs render top-to-bottom incrementally, which feels faster than baseline even at the same file size.

In HTML, use `<picture>` for explicit format negotiation:
```html
<picture>
  <source srcset="/img/hero.webp" type="image/webp">
  <img src="/img/hero.jpg" alt="..." width="1200" height="630">
</picture>
```

## Responsive Images with `sizes`

The browser picks from `srcset` using the `sizes` hint. Without `sizes`, it assumes 100vw and downloads a larger image than necessary.

```html
<img
  srcset="/img/hero-400.webp 400w, /img/hero-800.webp 800w, /img/hero-1200.webp 1200w"
  sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 800px"
  src="/img/hero-800.webp"
  alt="..."
  width="800"
  height="533"
/>
```

Always include `width` and `height` attributes — they prevent layout shift (CLS) by letting the browser reserve space before the image loads.

## LCP Images: `priority` / `fetchpriority`

The Largest Contentful Paint element is almost always the hero image. It must not be lazy-loaded — that would defeat the entire purpose.

**Next.js**: `<Image priority />` sets `fetchpriority="high"` and removes `loading="lazy"`.

**Vanilla HTML**: `<img fetchpriority="high" loading="eager">` — no `lazy` attribute.

Limit `priority` to 1–2 images per page. Marking everything as high priority is equivalent to marking nothing as high priority.

## Lazy Loading and Blurhash Placeholders

Images below the fold should use `loading="lazy"`. The browser defers fetching until the image is near the viewport.

For a smooth experience, show a low-resolution placeholder while the full image loads. Blurhash encodes a tiny (20–30 byte) string representing the image's color palette.

```ts
import { encode } from 'blurhash';

// At upload time, generate and store the hash
const blurhashString = encode(pixels, width, height, 4, 3);

// At render time, decode to a tiny canvas or CSS gradient
```

An alternative is a base64-encoded LQIP (Low Quality Image Placeholder) — a 20×15px JPEG encoded as a data URL, inlined into the HTML. Heavier than blurhash but no JS decoder needed.

## Sharp on the Server

Sharp wraps libvips — it's 4–5x faster than ImageMagick and processes images in streaming pipelines without loading the full file into memory.

Key Sharp defaults to set explicitly:
- `.resize(width, height, { fit: 'cover', position: 'attention' })` — `attention` mode crops toward the most visually interesting region.
- `.rotate()` — call with no args to auto-rotate based on EXIF orientation. Skip this and portrait phone photos display sideways.
- `.withMetadata(false)` — strip EXIF data to remove GPS coordinates, device info, and photographer metadata before public hosting.

## Upload Pipeline Integration

```
User uploads → validate mimetype (not just extension) → Sharp pipeline:
  1. Strip EXIF
  2. Auto-rotate
  3. Resize to max dimension (e.g., 2000px)
  4. Generate blurhash
  5. Output WebP + JPEG variants at each breakpoint
  6. Upload variants to storage (S3/Supabase Storage/Cloudflare R2)
  7. Store variant URLs + blurhash in DB
```

Never store the original file publicly — it may contain EXIF GPS data. Store originals in a private bucket; serve only optimized variants.

## Key Rules

- **Never serve original uploaded files** publicly — strip EXIF, resize, re-encode first.
- LCP images get `priority` / `fetchpriority="high"` and **no** `loading="lazy"`.
- Always set `width` and `height` on `<img>` to prevent **layout shift (CLS)**.
- Use `sizes` attribute to help the browser pick the right `srcset` variant.
- Call `sharp().rotate()` (no args) on every upload to fix **EXIF orientation**.
- Serve WebP with JPEG fallback via `<picture>` or `Accept` header detection.
- Store **blurhash** at upload time — computing it on the fly is too slow.
