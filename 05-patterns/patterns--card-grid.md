# Pattern: Card Grid

## Overview

Grid of cards for: product listings, service catalog, team members, blog posts, client list. Responsive — columns change at breakpoints.

## Basic Card Grid

```tsx
interface ServiceCard {
  id: string
  title: string
  description: string
  price?: string
  icon: string
  href?: string
}

interface CardGridProps {
  cards: ServiceCard[]
  columns?: 2 | 3 | 4
}

const GRID_CLASSES: Record<2 | 3 | 4, string> = {
  2: 'grid-cols-1 sm:grid-cols-2',
  3: 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3',
  4: 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-4',
}

export function CardGrid({ cards, columns = 3 }: CardGridProps) {
  return (
    <div className={`grid ${GRID_CLASSES[columns]} gap-6`}>
      {cards.map((card) => (
        <Card key={card.id} card={card} />
      ))}
    </div>
  )
}

function Card({ card }: { card: ServiceCard }) {
  const Wrapper = card.href ? 'a' : 'div'

  return (
    <Wrapper
      {...(card.href ? { href: card.href } : {})}
      className="group bg-white rounded-xl border p-6 hover:shadow-md transition-shadow"
    >
      <div className="text-3xl mb-3">{card.icon}</div>
      <h3 className="font-semibold text-gray-900 mb-2 group-hover:text-blue-600 transition-colors">
        {card.title}
      </h3>
      <p className="text-sm text-gray-600 leading-relaxed">{card.description}</p>
      {card.price && (
        <p className="mt-3 text-sm font-medium text-blue-600">{card.price}</p>
      )}
      {card.href && (
        <p className="mt-3 text-sm text-blue-600 font-medium group-hover:underline">
          Learn more →
        </p>
      )}
    </Wrapper>
  )
}
```

## Image Card Grid (Products / Portfolio)

```tsx
interface ImageCard {
  id: string
  title: string
  subtitle?: string
  imageUrl: string
  href?: string
}

function ImageCardGrid({ items }: { items: ImageCard[] }) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      {items.map((item) => (
        <div key={item.id} className="group rounded-xl overflow-hidden border bg-white">
          <div className="relative aspect-video overflow-hidden bg-gray-100">
            <Image
              src={item.imageUrl}
              alt={item.title}
              fill
              className="object-cover group-hover:scale-105 transition-transform duration-300"
              sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
            />
          </div>
          <div className="p-4">
            <h3 className="font-medium text-gray-900">{item.title}</h3>
            {item.subtitle && (
              <p className="text-sm text-gray-500 mt-1">{item.subtitle}</p>
            )}
          </div>
        </div>
      ))}
    </div>
  )
}
```

## Masonry Grid (Variable Heights)

```tsx
// CSS-based masonry — no JS, widths auto
function MasonryGrid({ items }: { items: ImageCard[] }) {
  return (
    <div
      className="columns-1 sm:columns-2 lg:columns-3 gap-4"
      style={{ columnFill: 'balance' }}
    >
      {items.map((item) => (
        <div key={item.id} className="break-inside-avoid mb-4">
          <Image
            src={item.imageUrl}
            alt={item.title}
            width={400}
            height={0}
            style={{ height: 'auto' }}  // Let height be natural
            className="w-full rounded-xl"
          />
        </div>
      ))}
    </div>
  )
}
```

`break-inside-avoid` prevents cards from being split across columns. `height: auto` lets images maintain their aspect ratio.

## Filterable Card Grid

```tsx
'use client'
import { useState, useMemo } from 'react'

function FilterableGrid({ cards, categories }: { cards: ServiceCard[]; categories: string[] }) {
  const [activeCategory, setActiveCategory] = useState<string>('all')

  const filtered = useMemo(
    () => activeCategory === 'all'
      ? cards
      : cards.filter((c) => c.category === activeCategory),
    [cards, activeCategory]
  )

  return (
    <div>
      {/* Filter pills */}
      <div className="flex flex-wrap gap-2 mb-6">
        {['all', ...categories].map((cat) => (
          <button
            key={cat}
            onClick={() => setActiveCategory(cat)}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-colors
              ${activeCategory === cat
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
          >
            {cat === 'all' ? 'All' : cat}
          </button>
        ))}
      </div>

      {/* Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        {filtered.map((card) => (
          <Card key={card.id} card={card} />
        ))}
      </div>

      {filtered.length === 0 && (
        <p className="text-center text-gray-500 py-12">No items in this category</p>
      )}
    </div>
  )
}
```

## Loading State

```tsx
function CardGridSkeleton({ count = 6 }: { count?: number }) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
      {Array.from({ length: count }, (_, i) => (
        <div key={i} className="rounded-xl border p-6 animate-pulse">
          <div className="w-10 h-10 bg-gray-200 rounded-lg mb-3" />
          <div className="h-4 bg-gray-200 rounded w-3/4 mb-2" />
          <div className="h-3 bg-gray-200 rounded w-full mb-1" />
          <div className="h-3 bg-gray-200 rounded w-5/6" />
        </div>
      ))}
    </div>
  )
}
```

## Responsive Column Defaults

- 1 column on mobile (< 640px): always default
- 2 columns on tablet (640–1024px): for most cards
- 3 columns on desktop (> 1024px): standard for content cards
- 4 columns: only for small data cards (stats, quick services)

Add `auto-rows-fr` to make all cards equal height in a row (prevents short cards leaving gaps):

```tsx
<div className="grid grid-cols-3 gap-6 auto-rows-fr">
```
