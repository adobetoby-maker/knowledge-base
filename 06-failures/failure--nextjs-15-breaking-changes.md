# Failure Patterns: Next.js 15 Breaking Changes

## Async params and searchParams

In Next.js 15, `params` and `searchParams` are now Promises. The most common source of TypeScript errors and runtime crashes.

```typescript
// NEXT.JS 14 — worked fine:
export default function Page({ params }: { params: { slug: string } }) {
  const { slug } = params  // direct destructure
}

// NEXT.JS 15 — params is a Promise:
export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params  // must await
}

// SAME for searchParams:
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; page?: string }>
}) {
  const { q, page } = await searchParams
}
```

This affects ALL page and layout components that receive params or searchParams.

## Async generateMetadata

```typescript
// Also affects generateMetadata:
export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>
}): Promise<Metadata> {
  const { slug } = await params  // must await
  return { title: slug }
}
```

## Caching Changes

Next.js 15 changed defaults: `fetch` is no longer cached by default. What was cached in v14 is now dynamic.

```typescript
// Next.js 14: cached by default (static)
const data = await fetch('/api/data')

// Next.js 15: NOT cached by default (dynamic)
const data = await fetch('/api/data')

// To cache in v15 (explicit):
const data = await fetch('/api/data', { cache: 'force-cache' })
// Or use ISR:
const data = await fetch('/api/data', { next: { revalidate: 3600 } })
```

Routes that were static in v14 may become dynamic in v15 causing unexpected fetch costs.

## cookies() and headers() Are Async

```typescript
// NEXT.JS 14:
import { cookies } from 'next/headers'
const cookieStore = cookies()
const session = cookieStore.get('session')

// NEXT.JS 15:
const cookieStore = await cookies()
const session = cookieStore.get('session')

// Same for headers():
const headersList = await headers()
const ip = headersList.get('x-forwarded-for')
```

## notFound() and redirect() in Try/Catch

In Next.js 15, `notFound()` and `redirect()` throw errors internally. Wrapping them in try/catch will catch the throw and break them.

```typescript
// WRONG:
try {
  const invoice = await fetchInvoice(id)
  if (!invoice) notFound()  // throws internally
} catch (error) {
  // This catches the notFound throw! Bad.
  console.error(error)
}

// CORRECT — call notFound() outside try/catch:
const invoice = await fetchInvoice(id)
if (!invoice) notFound()  // called outside try block

try {
  // other operations
} catch (error) {
  console.error(error)
}
```

## Edge Runtime Differences

Certain Node.js APIs are not available in Edge Runtime. If you accidentally added `export const runtime = 'edge'` to a route that uses Node.js-only features:

```typescript
// These fail in Edge Runtime:
import { readFileSync } from 'fs'         // not available
import { createHmac } from 'crypto'      // use Web Crypto instead
import sharp from 'sharp'                // native binary, use Node.js runtime

// Remove 'edge' runtime from routes using these
// Or add: export const runtime = 'nodejs'
```

## Default import for next/image Changed

```typescript
// Still works — no breaking change here
import Image from 'next/image'
```

No change, but worth noting: the `quality` default changed from 75 to something different in some versions. Always set `quality` explicitly for hero images.

## Turbopack as Default Dev Server

In Next.js 15, `next dev` uses Turbopack by default. This is faster but some webpack plugins/configs don't work.

```bash
# If Turbopack causes issues, fall back to webpack:
next dev --turbopack false
# or: next dev --no-turbopack
```

Most issues are with custom webpack loaders, MDX, or older CSS modules configurations.
