# TanStack Start vs Next.js — Critical Differences

## The Core Confusion

language-lens-elite uses TanStack Start (React Router v7 + Vite + Cloudflare Workers), NOT Next.js. Applying Next.js patterns to this project breaks it silently or loudly. Every time you touch language-lens-elite, verify: this is TanStack Start.

## File-Based Routing: Different Conventions

Next.js App Router:
```
app/
  page.tsx              → /
  blog/
    [slug]/
      page.tsx          → /blog/:slug
  layout.tsx            → root layout
```

TanStack Start (React Router v7):
```
src/routes/
  index.tsx             → / (root route with providers)
  blog.$slug.tsx        → /blog/:slug
  __root.tsx            → root layout/shell
```

Key differences:
- Dynamic params: `[slug]` in Next.js, `$slug` in TanStack Start
- Root layout: `layout.tsx` in Next.js, `__root.tsx` in TanStack Start
- Route file convention: `page.tsx` in Next.js, `routeName.tsx` in TanStack Start

## Server Functions vs Route Handlers

Next.js:
```typescript
// app/api/chat/route.ts
export async function POST(req: Request) { }
```

TanStack Start:
```typescript
// src/routes/api.chat.ts
import { createServerFn } from '@tanstack/start'

export const chatFn = createServerFn({ method: 'POST' })
  .validator(z.object({ message: z.string() }))
  .handler(async ({ data }) => {
    // server-side code runs here
  })
```

Server functions in TanStack Start are called directly from client components — no fetch URL needed. The framework handles serialization.

## No getServerSideProps, No generateStaticParams

These are Next.js-only patterns. They do not exist in TanStack Start.

TanStack Start data loading:
```typescript
// In a route file
export const Route = createFileRoute('/blog/$slug')({
  loader: async ({ params }) => {
    return await fetchBlogPost(params.slug)
  },
  component: BlogPost,
})

function BlogPost() {
  const post = Route.useLoaderData()  // typed, no async/await needed
}
```

## 'use client' Directive

In Next.js, `'use client'` marks a component as a Client Component (RSC boundary).

In TanStack Start + React Router, `'use client'` does NOT exist as a framework concept. All components run on the client by default. Server-side logic goes in `createServerFn` or route loaders.

If you write `'use client'` in language-lens-elite, it is ignored at best, breaking at worst.

## Vite vs Webpack/Turbopack

language-lens-elite uses Vite for bundling. This means:
- Config is `vite.config.ts`, not `next.config.js`
- Env vars use `import.meta.env.VITE_*`, not `process.env.NEXT_PUBLIC_*`
- HMR is Vite HMR, not Next.js Fast Refresh

```typescript
// Wrong (Next.js pattern)
const url = process.env.NEXT_PUBLIC_SUPABASE_URL

// Right (Vite pattern)
const url = import.meta.env.VITE_SUPABASE_URL
```

## Image Handling

No `next/image` component in TanStack Start. Use standard `<img>` tags or a Vite-compatible image optimization solution.

## Deployment Target

Next.js deploys to Vercel or anywhere via adapter.

language-lens-elite deploys to Cloudflare Workers via `@cloudflare/vite-plugin`. The Vite plugin transforms the TanStack Start app into a Workers-compatible bundle.

This means Workers runtime constraints apply: no Node.js builtins, `env` bindings for secrets, Web APIs only.

## What Stays the Same

React itself works the same way. All React hooks (useState, useEffect, useContext, useMemo, useCallback) work identically. TanStack Query works the same way. Zustand works the same way. Shadcn/ui components work. Tailwind works.

The differences are entirely in: routing conventions, data loading, server-side code execution, build/deploy pipeline, and environment variables.
