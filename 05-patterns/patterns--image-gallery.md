# Pattern: Image Gallery with Lightbox

## What This Solves

Image grids for portfolios, service galleries, and product photos need: responsive masonry or grid layout, a lightbox for full-size viewing, keyboard navigation in the lightbox, and lazy loading. The common mistake is loading full-resolution images in the grid — always use thumbnails in the grid, full size in the lightbox.

## Gallery Grid

```tsx
// components/ImageGallery.tsx
'use client'
import { useState } from 'react'
import Image from 'next/image'
import { Lightbox } from '@/components/Lightbox'

interface GalleryImage {
  id: string
  src: string
  alt: string
  width: number
  height: number
  thumbnail?: string  // smaller version for grid
}

interface ImageGalleryProps {
  images: GalleryImage[]
  columns?: 2 | 3 | 4
}

export function ImageGallery({ images, columns = 3 }: ImageGalleryProps) {
  const [activeIndex, setActiveIndex] = useState<number | null>(null)

  const colClass = {
    2: 'grid-cols-2',
    3: 'grid-cols-2 sm:grid-cols-3',
    4: 'grid-cols-2 sm:grid-cols-3 lg:grid-cols-4',
  }[columns]

  return (
    <>
      <div className={`grid ${colClass} gap-2`}>
        {images.map((image, index) => (
          <button
            key={image.id}
            className="relative aspect-square overflow-hidden rounded-lg bg-muted hover:opacity-90 transition-opacity focus:outline-none focus:ring-2 focus:ring-ring"
            onClick={() => setActiveIndex(index)}
            aria-label={`View ${image.alt}`}
          >
            <Image
              src={image.thumbnail ?? image.src}
              alt={image.alt}
              fill
              className="object-cover"
              sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 25vw"
              loading="lazy"
            />
          </button>
        ))}
      </div>

      {activeIndex !== null && (
        <Lightbox
          images={images}
          initialIndex={activeIndex}
          onClose={() => setActiveIndex(null)}
        />
      )}
    </>
  )
}
```

## Lightbox Component

```tsx
// components/Lightbox.tsx
'use client'
import { useEffect, useCallback, useState } from 'react'
import Image from 'next/image'
import { X, ChevronLeft, ChevronRight } from 'lucide-react'

interface LightboxProps {
  images: GalleryImage[]
  initialIndex: number
  onClose: () => void
}

export function Lightbox({ images, initialIndex, onClose }: LightboxProps) {
  const [index, setIndex] = useState(initialIndex)

  const prev = useCallback(() => setIndex(i => (i - 1 + images.length) % images.length), [images.length])
  const next = useCallback(() => setIndex(i => (i + 1) % images.length), [images.length])

  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
      if (e.key === 'ArrowLeft') prev()
      if (e.key === 'ArrowRight') next()
    }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [onClose, prev, next])

  // Prevent body scroll while lightbox is open
  useEffect(() => {
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = '' }
  }, [])

  const current = images[index]

  return (
    <div
      className="fixed inset-0 z-50 bg-black/90 flex items-center justify-center"
      onClick={onClose}
      role="dialog"
      aria-modal
      aria-label={`Image ${index + 1} of ${images.length}: ${current.alt}`}
    >
      {/* Close */}
      <button
        className="absolute top-4 right-4 text-white/80 hover:text-white"
        onClick={onClose}
        aria-label="Close"
      >
        <X className="h-6 w-6" />
      </button>

      {/* Prev */}
      {images.length > 1 && (
        <button
          className="absolute left-4 text-white/80 hover:text-white p-2"
          onClick={e => { e.stopPropagation(); prev() }}
          aria-label="Previous image"
        >
          <ChevronLeft className="h-8 w-8" />
        </button>
      )}

      {/* Image */}
      <div
        className="relative max-w-5xl max-h-[90vh] w-full h-full mx-16"
        onClick={e => e.stopPropagation()}
      >
        <Image
          src={current.src}
          alt={current.alt}
          fill
          className="object-contain"
          sizes="90vw"
          priority
        />
      </div>

      {/* Next */}
      {images.length > 1 && (
        <button
          className="absolute right-4 text-white/80 hover:text-white p-2"
          onClick={e => { e.stopPropagation(); next() }}
          aria-label="Next image"
        >
          <ChevronRight className="h-8 w-8" />
        </button>
      )}

      {/* Counter */}
      <div className="absolute bottom-4 left-1/2 -translate-x-1/2 text-white/60 text-sm">
        {index + 1} / {images.length}
      </div>
    </div>
  )
}
```

## Masonry Layout

For uneven aspect ratios, use CSS columns instead of grid:

```tsx
<div className="columns-2 sm:columns-3 gap-2 space-y-2">
  {images.map((image, i) => (
    <button
      key={image.id}
      className="relative w-full overflow-hidden rounded-lg break-inside-avoid"
      onClick={() => setActiveIndex(i)}
    >
      <Image
        src={image.thumbnail ?? image.src}
        alt={image.alt}
        width={image.width}
        height={image.height}
        className="w-full h-auto"
        loading="lazy"
      />
    </button>
  ))}
</div>
```

## Next.js Image Sizing Rule

For gallery grids, always provide accurate `sizes` so Next.js serves the right variant:
- 2-col: `"(max-width: 640px) 50vw, 33vw"`
- 3-col: `"(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 25vw"`

Without this, Next.js defaults to 100vw and serves unnecessarily large images.
