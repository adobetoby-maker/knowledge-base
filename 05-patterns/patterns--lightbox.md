# Pattern: Lightbox / Image Viewer

## Overview

A lightbox shows a full-screen or overlay view of an image when clicked, with navigation between images in a gallery. Used in: portfolios, product galleries, photo collections.

## Simple Single Image Lightbox

```tsx
import { useState, useEffect, useCallback } from 'react'
import { X, ChevronLeft, ChevronRight } from 'lucide-react'
import Image from 'next/image'

interface LightboxImage {
  src: string
  alt: string
  width: number
  height: number
}

export function Lightbox({
  images,
  initialIndex = 0,
  onClose,
}: {
  images: LightboxImage[]
  initialIndex?: number
  onClose: () => void
}) {
  const [current, setCurrent] = useState(initialIndex)

  const goPrev = useCallback(() => {
    setCurrent((i) => (i - 1 + images.length) % images.length)
  }, [images.length])

  const goNext = useCallback(() => {
    setCurrent((i) => (i + 1) % images.length)
  }, [images.length])

  // Keyboard navigation
  useEffect(() => {
    function handleKey(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
      if (e.key === 'ArrowLeft') goPrev()
      if (e.key === 'ArrowRight') goNext()
    }
    document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [onClose, goPrev, goNext])

  // Prevent body scroll
  useEffect(() => {
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = '' }
  }, [])

  const img = images[current]

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/90"
      onClick={onClose}  // Click backdrop to close
    >
      {/* Image container — stop propagation so clicking image doesn't close */}
      <div
        className="relative max-w-[90vw] max-h-[90vh]"
        onClick={(e) => e.stopPropagation()}
      >
        <Image
          src={img.src}
          alt={img.alt}
          width={img.width}
          height={img.height}
          className="max-h-[85vh] w-auto object-contain"
          priority
        />

        {/* Caption */}
        {img.alt && (
          <p className="mt-2 text-center text-sm text-white/70">{img.alt}</p>
        )}
      </div>

      {/* Close button */}
      <button
        className="absolute right-4 top-4 rounded-full bg-white/10 p-2 text-white hover:bg-white/20"
        onClick={onClose}
        aria-label="Close"
      >
        <X size={20} />
      </button>

      {/* Navigation — only show if multiple images */}
      {images.length > 1 && (
        <>
          <button
            className="absolute left-4 top-1/2 -translate-y-1/2 rounded-full bg-white/10 p-3 text-white hover:bg-white/20 disabled:opacity-30"
            onClick={(e) => { e.stopPropagation(); goPrev() }}
            aria-label="Previous image"
          >
            <ChevronLeft size={24} />
          </button>
          <button
            className="absolute right-4 top-1/2 -translate-y-1/2 rounded-full bg-white/10 p-3 text-white hover:bg-white/20 disabled:opacity-30"
            onClick={(e) => { e.stopPropagation(); goNext() }}
            aria-label="Next image"
          >
            <ChevronRight size={24} />
          </button>

          {/* Dot indicators */}
          <div className="absolute bottom-4 flex gap-1.5">
            {images.map((_, i) => (
              <button
                key={i}
                className={`h-1.5 rounded-full transition-all ${
                  i === current ? 'w-4 bg-white' : 'w-1.5 bg-white/40'
                }`}
                onClick={(e) => { e.stopPropagation(); setCurrent(i) }}
                aria-label={`Go to image ${i + 1}`}
              />
            ))}
          </div>
        </>
      )}
    </div>
  )
}
```

## Gallery with Lightbox Trigger

```tsx
'use client'
import { useState } from 'react'
import Image from 'next/image'
import { Lightbox } from './Lightbox'

const GALLERY_IMAGES = [
  { src: '/shop-front.jpg', alt: "JR's Auto Repair - Main Street", width: 1200, height: 800 },
  { src: '/shop-interior.jpg', alt: 'Shop interior with lift bays', width: 1200, height: 800 },
  { src: '/team.jpg', alt: 'Our team', width: 1200, height: 800 },
]

export function ShopGallery() {
  const [lightboxIndex, setLightboxIndex] = useState<number | null>(null)

  return (
    <>
      <div className="grid grid-cols-2 gap-2 md:grid-cols-3">
        {GALLERY_IMAGES.map((img, i) => (
          <button
            key={i}
            onClick={() => setLightboxIndex(i)}
            className="group relative aspect-square overflow-hidden rounded-lg"
            aria-label={`View ${img.alt}`}
          >
            <Image
              src={img.src}
              alt={img.alt}
              fill
              className="object-cover transition-transform duration-300 group-hover:scale-105"
              sizes="(max-width: 768px) 50vw, 33vw"
            />
          </button>
        ))}
      </div>

      {lightboxIndex !== null && (
        <Lightbox
          images={GALLERY_IMAGES}
          initialIndex={lightboxIndex}
          onClose={() => setLightboxIndex(null)}
        />
      )}
    </>
  )
}
```

## Touch Swipe Support

For mobile, add swipe gestures:

```tsx
const touchStartX = useRef(0)

<div
  onTouchStart={(e) => { touchStartX.current = e.touches[0].clientX }}
  onTouchEnd={(e) => {
    const delta = e.changedTouches[0].clientX - touchStartX.current
    if (Math.abs(delta) > 50) {
      if (delta > 0) goPrev()
      else goNext()
    }
  }}
>
  {/* image */}
</div>
```

## Focus Trap

The lightbox should trap focus for keyboard and screen reader accessibility:

```tsx
// Use Radix UI Dialog which handles focus trapping automatically
import * as Dialog from '@radix-ui/react-dialog'

export function AccessibleLightbox({ images, initialIndex, onClose }) {
  return (
    <Dialog.Root open onOpenChange={(open) => !open && onClose()}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 bg-black/90" />
        <Dialog.Content className="fixed inset-0 flex items-center justify-center">
          {/* image and controls */}
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}
```

Radix Dialog handles: focus trap, Escape key, ARIA attributes, return focus on close.
