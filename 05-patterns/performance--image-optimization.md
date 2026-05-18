---
name: image-optimization
description: Use when adding images, optimizing images, fixing slow
  load times caused by images, or preparing assets for deployment
---

# Image Optimization

## The Rules
1. Never ship unoptimized images — ever
2. Always WebP with fallback
3. Always width and height attributes
4. Hero images: preload + eager load
5. Everything else: lazy load
6. Use correct size for display size (no 4000px image for 400px display)

---

## Convert To WebP
```bash
# Install sharp-cli
npm install -g sharp-cli

# Convert single image
sharp -i hero.jpg -o hero.webp

# Convert with resize
sharp -i hero.jpg -o hero-1200.webp --resize 1200

# Batch convert all JPGs in folder
for f in *.jpg; do sharp -i "$f" -o "${f%.jpg}.webp"; done

# Using ImageMagick
convert hero.jpg -quality 85 hero.webp
```

## Generate Responsive Sizes
```bash
# Generate multiple sizes for srcset
sharp -i hero.jpg -o hero-400.webp  --resize 400
sharp -i hero.jpg -o hero-800.webp  --resize 800
sharp -i hero.jpg -o hero-1200.webp --resize 1200
sharp -i hero.jpg -o hero-1600.webp --resize 1600
```

---

## Responsive Image Pattern
```html
<!-- Hero image (above fold) — NEVER lazy load -->
<picture>
  <source 
    srcset="
      /images/hero-400.avif  400w,
      /images/hero-800.avif  800w,
      /images/hero-1200.avif 1200w,
      /images/hero-1600.avif 1600w
    "
    type="image/avif"
  />
  <source 
    srcset="
      /images/hero-400.webp  400w,
      /images/hero-800.webp  800w,
      /images/hero-1200.webp 1200w,
      /images/hero-1600.webp 1600w
    "
    type="image/webp"
  />
  <img 
    src="/images/hero-1200.jpg"
    width="1200"
    height="630"
    alt="Descriptive alt text here"
    loading="eager"
    fetchpriority="high"
  />
</picture>

<!-- Below fold image — always lazy load -->
<picture>
  <source srcset="/images/feature.webp" type="image/webp" />
  <img 
    src="/images/feature.jpg"
    width="600"
    height="400"
    alt="Descriptive alt text"
    loading="lazy"
    decoding="async"
  />
</picture>
```

---

## React Image Component
```tsx
interface OptimizedImageProps {
  src: string
  alt: string
  width: number
  height: number
  priority?: boolean
  className?: string
}

export const OptimizedImage = ({
  src,
  alt,
  width,
  height,
  priority = false,
  className = ''
}: OptimizedImageProps) => {
  const webpSrc = src.replace(/\.(jpg|jpeg|png)$/i, '.webp')
  
  return (
    <picture>
      <source srcSet={webpSrc} type="image/webp" />
      <img
        src={src}
        alt={alt}
        width={width}
        height={height}
        loading={priority ? 'eager' : 'lazy'}
        decoding={priority ? 'sync' : 'async'}
        fetchPriority={priority ? 'high' : 'auto'}
        className={className}
        style={{ maxWidth: '100%', height: 'auto' }}
      />
    </picture>
  )
}
```

---

## Preload Hero Image
```html
<!-- In <head> — before any CSS -->
<link 
  rel="preload" 
  as="image" 
  href="/images/hero.webp"
  imagesrcset="/images/hero-400.webp 400w, /images/hero-1200.webp 1200w"
  imagesizes="100vw"
/>
```

---

## Image Size Targets
```
Hero (full width):    < 200kb at 1200px
Card image:           < 80kb at 600px  
Thumbnail:            < 30kb at 200px
Avatar:               < 15kb at 100px
Icon:                 SVG preferred, < 5kb
OG image:             < 300kb at 1200x630
```

---

## Automated Check Script
```bash
#!/bin/bash
# check-image-sizes.sh
# Run before every deploy

LIMIT=300000 # 300kb
FAIL=0

for img in public/images/*; do
  size=$(wc -c < "$img")
  if [ $size -gt $LIMIT ]; then
    echo "❌ TOO LARGE: $img ($((size/1024))kb)"
    FAIL=1
  fi
done

if [ $FAIL -eq 0 ]; then
  echo "✅ All images within size limits"
fi

exit $FAIL
```

---

## Image Fallbacks

### WebP not supported (rare in 2026)
```html
<picture>
  <source srcset="image.webp" type="image/webp" />
  <img src="image.jpg" /> <!-- fallback -->
</picture>
```

### Image fails to load
```css
/* Style broken images gracefully */
img {
  background: #f3f4f6;
  min-height: 100px;
}

img::after {
  content: 'Image unavailable';
  display: flex;
  align-items: center;
  justify-content: center;
  color: #6b7280;
  font-size: 0.875rem;
}
```

### CLS from images loading
```css
/* Reserve space before image loads */
.image-wrapper {
  aspect-ratio: 16 / 9;
  background: #f3f4f6;
  overflow: hidden;
}

.image-wrapper img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
```

### Blurry images on retina screens
```html
<!-- Provide 2x for retina -->
<img 
  srcset="image.webp 1x, image@2x.webp 2x"
  src="image.webp"
/>
```

### Images slow on Cloudflare
```
Cloudflare Polish (free): automatically converts to WebP
Enable: Dashboard → Speed → Optimization → Polish
Set to: Lossless or Lossy
This handles conversion automatically for supported browsers
```
