# Plugin: SuperJSON

## Overview

SuperJSON serializes JavaScript types that standard `JSON.stringify` can't handle: `Date`, `Map`, `Set`, `BigInt`, `undefined`, `NaN`, `Infinity`, and class instances. It produces a lossless JSON representation that can be deserialized back to the original type. Use in tRPC, React Server Component data passing, and localStorage caching of typed data.

## Installation

```bash
npm install superjson
```

## Basic Usage

```ts
import superjson from 'superjson'

const data = {
  createdAt: new Date('2024-01-15'),
  amount: BigInt(9007199254740993),
  tags: new Set(['js', 'typescript']),
  meta: new Map([['version', 2], ['env', 'prod']]),
  empty: undefined,
}

// Serialize
const serialized = superjson.stringify(data)
// → Extended JSON string with type metadata

// Deserialize — restores original types
const restored = superjson.parse<typeof data>(serialized)
restored.createdAt instanceof Date  // true
restored.amount === BigInt(9007199254740993)  // true
restored.tags instanceof Set  // true
```

## Next.js: Server → Client Data Passing

React Server Components serialize data as JSON automatically. When your server data includes `Date` objects, they become strings by default. SuperJSON fixes this:

```tsx
// In a React Server Component
import { createServerSideHelpers } from '@trpc/react-query/server'
import superjson from 'superjson'

export default async function ProductPage({ params }) {
  const product = await db.query.products.findFirst({
    where: eq(products.slug, params.slug),
  })
  // product.createdAt is a Date

  // Pass to client without type loss:
  const serialized = superjson.serialize(product)

  return (
    <ClientProductView
      productJson={serialized.json}
      productMeta={serialized.meta}
    />
  )
}

// Client Component
'use client'
function ClientProductView({ productJson, productMeta }: { productJson: unknown; productMeta: unknown }) {
  const product = superjson.deserialize({ json: productJson, meta: productMeta })
  // product.createdAt is a Date again
}
```

## tRPC Integration

```ts
// server/trpc.ts
import { initTRPC } from '@trpc/server'
import superjson from 'superjson'

const t = initTRPC.create({
  transformer: superjson,  // Handles Date/BigInt/Map/Set in all tRPC responses
})

export const router = t.router
export const publicProcedure = t.procedure
```

## LocalStorage with Types

```ts
function setStorageItem<T>(key: string, value: T): void {
  localStorage.setItem(key, superjson.stringify(value))
}

function getStorageItem<T>(key: string): T | null {
  const raw = localStorage.getItem(key)
  if (!raw) return null
  try {
    return superjson.parse<T>(raw)
  } catch {
    return null
  }
}

// Dates survive storage/retrieval
setStorageItem('lastLogin', { date: new Date(), user: 'alice' })
const saved = getStorageItem<{ date: Date; user: string }>('lastLogin')
saved?.date instanceof Date  // true
```

## Zod + SuperJSON

```ts
import { z } from 'zod'
import superjson from 'superjson'

// Schema validates the deserialized types
const SessionSchema = z.object({
  userId: z.string(),
  expiresAt: z.date(),
  roles: z.set(z.string()),
})

function parseSession(serialized: string) {
  const parsed = superjson.parse(serialized)
  return SessionSchema.parse(parsed)
}
```

## Key Rules

- SuperJSON adds a `meta` field alongside `json` — both are required for deserialization to restore types.
- `superjson.stringify` / `superjson.parse` work like `JSON.stringify`/`JSON.parse` for the simple case.
- For `superjson.serialize` / `superjson.deserialize`, you handle the `{ json, meta }` object separately — use when you need to pass them as distinct props.
- Don't use SuperJSON in performance-critical hot paths — it's ~3x slower than `JSON.stringify` due to type metadata generation.
- In Next.js App Router, prefer `JSON.stringify` with explicit `.toISOString()` for dates if you only need dates — SuperJSON is most valuable for `Map`/`Set`/`BigInt`.
