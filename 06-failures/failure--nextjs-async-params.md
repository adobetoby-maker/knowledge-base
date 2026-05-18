# Next.js 15 Async Params Breaking Change

## The Change

In Next.js 15, `params` and `searchParams` in pages, layouts, and Route Handlers are now Promises. They must be awaited.

This is one of the most common sources of bugs when writing Next.js code from pre-2025 training data or documentation.

## Symptoms

```
TypeError: params.slug is undefined
TypeError: Cannot read properties of undefined (reading 'id')
params.slug: Promise { ... }  // logged value shows it's a Promise, not an object
```

## Wrong (Next.js 14 and earlier)

```typescript
// WRONG — params not awaited
export default function BlogPost({ params }: { params: { slug: string } }) {
  return <h1>{params.slug}</h1>  // params.slug is undefined in Next.js 15
}

// WRONG — searchParams not awaited
export default function SearchPage({
  searchParams,
}: {
  searchParams: { q: string }
}) {
  const query = searchParams.q  // undefined in Next.js 15
}

// WRONG — generateMetadata not awaiting params
export async function generateMetadata({ params }: { params: { slug: string } }) {
  return { title: params.slug }  // params.slug is undefined
}
```

## Correct (Next.js 15+)

```typescript
// CORRECT — await params in async component
export default async function BlogPost({
  params,
}: {
  params: Promise<{ slug: string }>
}) {
  const { slug } = await params
  return <h1>{slug}</h1>
}

// CORRECT — await searchParams
export default async function SearchPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>
}) {
  const { q = '' } = await searchParams
  // ...
}

// CORRECT — generateMetadata
export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>
}): Promise<Metadata> {
  const { slug } = await params
  return { title: slug }
}

// CORRECT — generateStaticParams (returns array, no await needed)
export async function generateStaticParams() {
  const articles = await getArticles()
  return articles.map(a => ({ slug: a.slug }))
}
```

## Route Handlers

```typescript
// CORRECT in Route Handlers
export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  // ...
}
```

## Interleaving Client and Server

Client Components receiving params from Server Component parents:

```typescript
// Server Component (parent) — awaits params
export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  return <ClientComponent id={id} />  // pass the resolved value
}

// Client Component (child) — receives resolved string, not Promise
'use client'
export function ClientComponent({ id }: { id: string }) {
  // id is a string here — parent awaited it
}
```

## Quick Check

If you see a TypeScript error like:
```
Type 'Promise<{ slug: string }>' has no property 'slug'
```

or a runtime error like:
```
Cannot read properties of undefined
```

on `params.slug` or `searchParams.q`, the fix is always to:
1. Change the type from `{ slug: string }` to `Promise<{ slug: string }>`
2. Add `const { slug } = await params` before using the value

## Reference

The `next/dist/docs/` directory in any Next.js 15+ installation contains current documentation. Read it before writing Next.js route code.
