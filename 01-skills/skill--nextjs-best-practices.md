# Skill: nextjs-best-practices

**Trigger:** Working in any Next.js App Router project. Writing Server Components, Route Handlers, metadata, layouts, loading states, error boundaries.
**Invoke:** `/nextjs-best-practices`
**Returns:** Opinionated patterns for App Router, RSC, caching, data fetching, route handlers.

## When to Invoke
- Starting work in any `app/` directory
- Unsure whether component should be Server or Client
- Writing a new route with data fetching
- Setting up metadata for SEO
- Configuring caching behavior
- Before writing any `useEffect` to fetch data

## Core Rules This Skill Enforces

### Server vs Client Decision
```
Does component need: useState, useEffect, browser events, browser APIs?
→ YES → 'use client' at top of file
→ NO  → Server Component by default (no directive needed)
```

### Data Fetching
```typescript
// Server Component — fetch directly in component body
async function Page({ params }: { params: { id: string } }) {
  const data = await db.query(params.id)  // runs on server
  return <div>{data.name}</div>
}
```

### Caching Configuration
```typescript
// Static (default) — cached forever
export const dynamic = 'force-static'

// Dynamic — never cached
export const dynamic = 'force-dynamic'

// Revalidate every N seconds
export const revalidate = 3600

// Fetch-level cache control
const data = await fetch(url, { next: { revalidate: 60 } })
```

### Route Handler Pattern
```typescript
// app/api/users/[id]/route.ts
export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  const data = await getUser(params.id)
  if (!data) return Response.json({ error: 'Not found' }, { status: 404 })
  return Response.json(data)
}
```

### Metadata
```typescript
// Static
export const metadata: Metadata = {
  title: 'Page Title',
  description: 'Page description for SEO'
}

// Dynamic
export async function generateMetadata({ params }) {
  const post = await getPost(params.slug)
  return { title: post.title, description: post.excerpt }
}
```

### Loading and Error States
```
app/
  dashboard/
    page.tsx        ← actual content
    loading.tsx     ← shown while page.tsx resolves
    error.tsx       ← shown if page.tsx throws
    not-found.tsx   ← shown if notFound() called
```

## Critical Gotchas
- `cookies()` and `headers()` in Server Components forces dynamic rendering
- Importing a Client Component into a Server Component is fine
- Importing a Server Component into a Client Component: wrap in `{children}` pattern instead
- Never use `useRouter` in Server Components — it doesn't exist there
- `params` in App Router is now a Promise in Next.js 15+ — `await params` before accessing

## What Skill Returns
Detailed RSC patterns, caching strategies, composition patterns, suspense boundaries, and migration guides from Pages Router.
