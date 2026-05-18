# Pattern: Image with Fallback

## Overview
A broken image icon is one of the most visually unprofessional things a UI can show. Users also experience layout shift and FOUT-like flashes when images load without placeholders. This pattern eliminates both by handling load states explicitly and always substituting gracefully on error.

## Implementation

```tsx
// ImageWithFallback.tsx
import { useState } from 'react'

interface ImageWithFallbackProps {
  src: string
  alt: string
  fallbackSrc?: string
  blurhash?: string          // base64 LQIP data URI
  width: number
  height: number
  priority?: boolean         // true = above-the-fold (LCP candidate)
  className?: string
}

export function ImageWithFallback({
  src,
  alt,
  fallbackSrc = '/images/placeholder.svg',
  blurhash,
  width,
  height,
  priority = false,
  className,
}: ImageWithFallbackProps) {
  const [loaded, setLoaded] = useState(false)
  const [errored, setErrored] = useState(false)

  // If the primary src fails, swap to fallback
  // If fallback also fails, we've already shown the placeholder svg
  const resolvedSrc = errored ? fallbackSrc : src

  return (
    <div
      style={{
        position: 'relative',
        width,
        height,
        overflow: 'hidden',
        // Prevent layout shift: reserve space before image loads
        background: loaded ? undefined : (blurhash ?? '#f0f0f0'),
      }}
    >
      {/* Skeleton shimmer — visible until image loads */}
      {!loaded && (
        <div
          aria-hidden
          style={{
            position: 'absolute',
            inset: 0,
            background: 'linear-gradient(90deg, #e0e0e0 25%, #f5f5f5 50%, #e0e0e0 75%)',
            backgroundSize: '200% 100%',
            animation: 'shimmer 1.5s infinite',
          }}
        />
      )}

      <img
        src={resolvedSrc}
        alt={alt}
        width={width}
        height={height}
        // LCP exception: images above the fold must load eagerly
        // lazy-loading them hurts Core Web Vitals
        loading={priority ? 'eager' : 'lazy'}
        // fetchpriority hints the browser to prioritize this fetch
        fetchPriority={priority ? 'high' : 'auto'}
        decoding={priority ? 'sync' : 'async'}
        className={className}
        onLoad={() => setLoaded(true)}
        onError={() => {
          // Only swap to fallback once — avoid infinite loop if
          // the fallback itself is broken
          if (!errored) setErrored(true)
        }}
        style={{
          display: 'block',
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          // Hide until loaded to prevent flash of broken layout
          opacity: loaded ? 1 : 0,
          transition: 'opacity 200ms ease',
        }}
      />
    </div>
  )
}
```

```css
/* Global shimmer keyframe — add once to your global CSS */
@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

```tsx
// Usage examples

// Hero image — priority=true because it's the LCP element
<ImageWithFallback
  src="/hero.jpg"
  alt="Team photo"
  width={1200}
  height={600}
  priority={true}
  blurhash="data:image/jpeg;base64,/9j/4AAQSkZ..."
/>

// Card thumbnail — lazy-loaded (below the fold)
<ImageWithFallback
  src={product.imageUrl}
  alt={product.name}
  width={400}
  height={300}
  fallbackSrc="/images/product-placeholder.svg"
/>
```

```tsx
// Next.js variant using next/image (handles most of this automatically)
import Image from 'next/image'
import { useState } from 'react'

export function NextImageWithFallback({ src, fallbackSrc = '/placeholder.svg', ...props }) {
  const [imgSrc, setImgSrc] = useState(src)

  return (
    <Image
      {...props}
      src={imgSrc}
      onError={() => setImgSrc(fallbackSrc)}
      placeholder="blur"
      blurDataURL="data:image/jpeg;base64,..."
    />
  )
}
```

## Key Rules
- Never let the browser show a broken image icon — always have an `onError` fallback src ready.
- Guard against infinite error loops: only swap to fallback once (`if (!errored) setErrored(true)`).
- Reserve the image's dimensions before it loads (width/height on the container) to prevent layout shift.
- Use `loading="lazy"` on all images except the LCP candidate (hero, first product image above fold).
- Mark the LCP image with `priority` / `fetchpriority="high"` and `loading="eager"`.
- Show a shimmer skeleton during load, not a blank white box.
- If you have LQIP (Low Quality Image Placeholder) or blurhash data, use it as the container background — it shows instantly and makes loading feel fast.
- The fade-in transition (`opacity 0 → 1`) on load prevents a jarring pop-in.
- The fallback src must be a reliable static file, never another dynamic URL that could also fail.
