# TanStack Start

## What It Is

TanStack Start is a full-stack React framework built on TanStack Router (React Router v7). Used in `language-lens-elite`.

Key differences from Next.js:
- File-based routing with `$param` syntax (not `[param]`)
- Server functions instead of Route Handlers or Server Actions
- Vite-based (not webpack/Turbopack)
- No 'use client' directive — component boundary is different
- `import.meta.env.VITE_*` for env vars (not `process.env` or `NEXT_PUBLIC_`)

## Route Files

```
src/routes/
  __root.tsx          → root layout (wraps everything)
  index.tsx           → / route
  about.tsx           → /about
  blog/
    index.tsx         → /blog
    $slug.tsx         → /blog/[slug]  (NOT [slug].tsx)
  api/
    items.ts          → /api/items
```

## Page Component Pattern

```typescript
// src/routes/blog/$slug.tsx
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/blog/$slug')({
  component: BlogPostPage,
  loader: async ({ params }) => {
    // params.slug available here
    return fetchArticle(params.slug)
  },
})

function BlogPostPage() {
  const article = Route.useLoaderData()
  const { slug } = Route.useParams()
  
  return <article>{article.title}</article>
}
```

## Server Functions (Not Route Handlers)

```typescript
// src/fns/items.functions.ts
import { createServerFn } from '@tanstack/react-start'
import { z } from 'zod'

const CreateItemSchema = z.object({
  name: z.string().min(1),
})

export const createItem = createServerFn({ method: 'POST' })
  .validator(CreateItemSchema)
  .handler(async ({ data }) => {
    const item = await db.items.create(data)
    return item
  })

// Usage in component:
const mutation = useMutation({
  mutationFn: (input) => createItem({ data: input }),
})
```

## Environment Variables

```typescript
// NEXT.JS:
process.env.NEXT_PUBLIC_SUPABASE_URL

// TANSTACK START (Vite):
import.meta.env.VITE_SUPABASE_URL

// Environment file:
// .env or .env.local
VITE_SUPABASE_URL=https://...
VITE_SUPABASE_PUBLISHABLE_KEY=eyJ...

// Server-only (no VITE_ prefix — not exposed to browser):
ANTHROPIC_API_KEY=sk-ant-...
```

## Supabase Client Pattern

```typescript
// src/integrations/supabase/client.ts
import { createClient } from '@supabase/supabase-js'

// Lazy proxy to avoid init errors at module load time:
let _client: ReturnType<typeof createClient> | null = null

function getClient() {
  if (_client) return _client
  
  const url = import.meta.env.VITE_SUPABASE_URL
    ?? process.env.VITE_SUPABASE_URL  // SSR fallback
  const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY
    ?? process.env.VITE_SUPABASE_PUBLISHABLE_KEY
  
  _client = createClient(url, key)
  return _client
}

export const supabase = new Proxy({} as ReturnType<typeof createClient>, {
  get: (_, prop) => (getClient() as any)[prop],
})
```

## Provider Stack

All providers stacked in `src/routes/__root.tsx`:

```typescript
// Order matters — auth must wrap everything that needs user:
<AuthProvider>
  <AppProvider>
    <LibraryProvider>
      {children}
    </LibraryProvider>
  </AppProvider>
</AuthProvider>
```

## No 'use client' Directive

TanStack Start components are client-side by default (Vite = browser bundle). Server functions run on the server via `createServerFn`. There is no 'use client' / 'use server' paradigm.

## Differences from Next.js at a Glance

| Feature | Next.js | TanStack Start |
|---|---|---|
| Dynamic route | `[slug]/page.tsx` | `$slug.tsx` |
| Server functions | Server Actions / Route Handlers | `createServerFn` |
| Env vars | `process.env.NEXT_PUBLIC_*` | `import.meta.env.VITE_*` |
| Client/Server boundary | `'use client'` | N/A — Vite handles it |
| Build tool | Turbopack/webpack | Vite |
| Deploy | Vercel, Node.js | Cloudflare Workers, Node.js |
