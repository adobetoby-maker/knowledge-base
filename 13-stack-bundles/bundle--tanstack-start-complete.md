# Bundle: TanStack Start Complete Reference

## Overview

TanStack Start is a full-stack React framework built on TanStack Router. Unlike Next.js, it uses a file-based routing system that's type-safe end-to-end, with server functions that run on the server but are called from the client like regular functions.

## Stack

```
TanStack Start (framework)
  ├── TanStack Router (file-based, type-safe routing)
  ├── Vite (build + dev server)
  ├── @cloudflare/vite-plugin (CF Workers runtime)
  ├── Vinxi (SSR bundling)
  └── TanStack Query (client data fetching, optional)
```

## File Structure

```
src/
  routes/
    __root.tsx          ← Root layout (HTML shell, providers)
    index.tsx           ← / route
    about.tsx           ← /about route
    blog/
      index.tsx         ← /blog route
      $slug.tsx         ← /blog/$slug route
    _auth/              ← Layout group (prefix underscore = layout-only, no URL segment)
      route.tsx         ← Auth check layout
      dashboard.tsx     ← /dashboard route
    api/
      users.ts          ← /api/users server endpoint
  fns/                  ← Server functions
    user.functions.ts
  integrations/
    supabase/
      client.ts
  components/
  state/
```

## Route File Structure

```tsx
// src/routes/blog/$slug.tsx
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/blog/$slug')({
  // Loader: runs on server (SSR) or before navigation
  loader: async ({ params }) => {
    return await getPost(params.slug)  // Use loader data in component
  },

  // Component: receives loader data typed automatically
  component: BlogPostPage,
  
  // Error boundary for this route
  errorComponent: ({ error }) => <div>Error: {error.message}</div>,
  
  // Pending (loading) state
  pendingComponent: () => <Skeleton />,
})

function BlogPostPage() {
  const post = Route.useLoaderData()  // Fully typed from loader return
  const { slug } = Route.useParams()

  return <article>{post.title}</article>
}
```

## Root Layout

```tsx
// src/routes/__root.tsx
import { createRootRoute, Outlet } from '@tanstack/react-router'

export const Route = createRootRoute({
  component: RootLayout,
})

function RootLayout() {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </head>
      <body>
        <Providers>
          <Outlet />  {/* Child routes render here */}
        </Providers>
      </body>
    </html>
  )
}
```

## Server Functions (Key Differentiator)

Server functions run on the server but are called from the client like regular async functions. No separate API layer needed:

```ts
// src/fns/user.functions.ts
import { createServerFn } from '@tanstack/start'
import { z } from 'zod'

const UpdateProfileSchema = z.object({
  displayName: z.string().min(1).max(50),
  bio: z.string().max(500).optional(),
})

export const updateProfile = createServerFn({ method: 'POST' })
  .validator(UpdateProfileSchema)
  .handler(async ({ data }) => {
    // Runs on server — can access DB, secrets
    const user = await requireAuth()  // Auth check
    await db.update(users)
      .set({ displayName: data.displayName, bio: data.bio })
      .where(eq(users.id, user.id))
    
    return { success: true }
  })
```

```tsx
// src/components/ProfileForm.tsx — calling from client
import { updateProfile } from '../fns/user.functions'

function ProfileForm() {
  async function handleSubmit(values: FormValues) {
    await updateProfile({ data: values })  // ← Calls server, type-safe
  }
}
```

## Navigation

```tsx
import { Link, useNavigate, useRouter } from '@tanstack/react-router'

// Type-safe links (TS knows valid routes)
<Link to="/blog/$slug" params={{ slug: post.slug }}>Read more</Link>
<Link to="/dashboard">Dashboard</Link>

// Programmatic navigation
const navigate = useNavigate()
await navigate({ to: '/dashboard', search: { tab: 'invoices' } })

// Back navigation
const router = useRouter()
router.history.back()
```

## URL Search Params (Type-Safe)

```tsx
const Route = createFileRoute('/invoices')({
  validateSearch: z.object({
    status: z.enum(['all', 'paid', 'pending']).default('all'),
    page: z.number().int().min(1).default(1),
  }),
  component: InvoicesPage,
})

function InvoicesPage() {
  const { status, page } = Route.useSearch()
  // status is typed as 'all' | 'paid' | 'pending'
  // page is typed as number
}
```

## Cloudflare Workers Integration

```ts
// app.config.ts
import { defineConfig } from '@tanstack/start/config'
import cloudflareDevProxy from '@cloudflare/vite-plugin'

export default defineConfig({
  server: {
    preset: 'cloudflare-pages',
  },
  vite: {
    plugins: [
      cloudflareDevProxy(),
    ],
  },
})
```

Environment in CF Workers:
```ts
import { getWebRequest } from '@tanstack/start/server'

export const getCloudflareEnv = createServerFn().handler(async () => {
  const request = getWebRequest()
  const cf = (request as unknown as { cf?: { env: unknown } }).cf
  return cf?.env as CloudflareEnv
})
```

## Differences from Next.js

| Feature | TanStack Start | Next.js |
|---------|---------------|---------|
| Routing | Type-safe, explicit | File-based, string paths |
| Data loading | `loader` functions | `fetch` in RSC |
| Server functions | `createServerFn()` | Server Actions |
| Bundle | Vite | Turbopack/webpack |
| CF Workers | First-class via plugin | Via @opennextjs/cloudflare |
| RSC | No (client components) | Yes |
| Learning curve | Higher | Lower (more common) |
