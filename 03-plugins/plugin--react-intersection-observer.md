# Plugin: react-intersection-observer

## Overview

`react-intersection-observer` wraps the browser's `IntersectionObserver` API in a React hook. Use it for: lazy-loading content when it enters the viewport, triggering animations on scroll, infinite scroll triggers, and tracking element visibility for analytics.

## Installation

```bash
npm install react-intersection-observer
```

## Basic Usage

```tsx
import { useInView } from 'react-intersection-observer'

export function FadeInSection({ children }: { children: React.ReactNode }) {
  const { ref, inView } = useInView({
    triggerOnce: true,    // Only trigger once, not every scroll in/out
    threshold: 0.1,       // 10% of element must be visible
  })

  return (
    <div
      ref={ref}
      className={`transition-all duration-700 ${
        inView ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
      }`}
    >
      {children}
    </div>
  )
}
```

`triggerOnce: true` is the right default for entrance animations — you don't want elements fading in every time you scroll past them.

## Lazy-Loading Images

```tsx
import { useInView } from 'react-intersection-observer'
import Image from 'next/image'

export function LazyImage({ src, alt, ...props }: ImageProps) {
  const { ref, inView } = useInView({
    triggerOnce: true,
    rootMargin: '200px',  // Start loading 200px before entering viewport
  })

  return (
    <div ref={ref} className="relative">
      {inView ? (
        <Image src={src} alt={alt} {...props} />
      ) : (
        <div className="bg-gray-200 animate-pulse" style={{ aspectRatio: '16/9' }} />
      )}
    </div>
  )
}
```

`rootMargin: '200px'` preloads images before they're visible — prevents the flash of placeholder as user scrolls. For hero images above the fold, skip the intersection check entirely.

## Infinite Scroll Trigger

```tsx
import { useInView } from 'react-intersection-observer'
import { useEffect } from 'react'

export function InfiniteScrollTrigger({
  onLoadMore,
  hasMore,
  loading,
}: {
  onLoadMore: () => void
  hasMore: boolean
  loading: boolean
}) {
  const { ref, inView } = useInView({ threshold: 0 })

  useEffect(() => {
    if (inView && hasMore && !loading) {
      onLoadMore()
    }
  }, [inView, hasMore, loading, onLoadMore])

  if (!hasMore) return null

  return (
    <div ref={ref} className="flex justify-center py-8">
      {loading && (
        <div className="w-6 h-6 border-2 border-blue-600 border-t-transparent rounded-full animate-spin" />
      )}
    </div>
  )
}
```

Place this component after the list. When it enters the viewport, `onLoadMore` fires. The `!loading` guard prevents double-firing.

## Section Analytics

```tsx
import { useInView } from 'react-intersection-observer'
import { useEffect, useRef } from 'react'
import posthog from 'posthog-js'

export function TrackedSection({ name, children }: { name: string; children: React.ReactNode }) {
  const { ref, inView } = useInView({ threshold: 0.5, triggerOnce: true })
  const tracked = useRef(false)

  useEffect(() => {
    if (inView && !tracked.current) {
      posthog.capture('section_viewed', { section: name })
      tracked.current = true
    }
  }, [inView, name])

  return <section ref={ref}>{children}</section>
}
```

The `tracked.current` ref is a belt-and-suspenders guard against the `triggerOnce` option. PostHog events should fire exactly once per session view.

## Multiple Elements

```tsx
// Track multiple items independently
function ProductList({ products }: { products: Product[] }) {
  return (
    <div>
      {products.map((product) => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  )
}

function ProductCard({ product }: { product: Product }) {
  const { ref, inView } = useInView({ triggerOnce: true })
  // Each card has its own observer
  return <div ref={ref} className={inView ? 'opacity-100' : 'opacity-0'}>{...}</div>
}
```

Each component instance gets its own observer — no shared state needed.

## `observe` Component API

For non-hook usage (wrapping third-party components):

```tsx
import { InView } from 'react-intersection-observer'

<InView triggerOnce threshold={0.1}>
  {({ ref, inView }) => (
    <div ref={ref} className={inView ? 'visible' : 'invisible'}>
      Content
    </div>
  )}
</InView>
```

## Browser Compatibility

IntersectionObserver is supported in all modern browsers. For IE11 support (increasingly rare), add the `intersection-observer` polyfill:

```ts
// Only import polyfill if needed
if (!('IntersectionObserver' in window)) {
  await import('intersection-observer')
}
```

In most projects, skip the polyfill — IE11 usage is negligible.
