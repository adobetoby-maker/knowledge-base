# Disambig: TanStack Start vs Next.js

## Overview
TanStack Start is a Vite-powered, edge-native React framework built on React Router v7 (file-based routing). Next.js is the industry-standard React framework with the largest ecosystem, Vercel integration, and the most production deployments. TanStack Start was designed to run natively on Cloudflare Workers and other V8 runtimes where Node.js APIs are unavailable. Next.js is the right default for most use cases.

## Implementation / Key Points

### Next.js
```ts
// app/blog/[slug]/page.tsx — App Router file-based routing
export default async function BlogPost({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug);
  return <article>{post.body}</article>;
}

// Data fetching via Route Handlers (not server functions)
// app/api/posts/route.ts
export async function GET(req: Request) {
  return Response.json(await getPosts());
}
```

### TanStack Start
```ts
// src/routes/blog.$slug.tsx — React Router v7 file-based routing
import { createFileRoute } from '@tanstack/react-router';
import { createServerFn } from '@tanstack/start';

const getPost = createServerFn({ method: 'GET' })
  .validator(z.object({ slug: z.string() }))
  .handler(async ({ data }) => getPost(data.slug));

export const Route = createFileRoute('/blog/$slug')({
  loader: ({ params }) => getPost({ data: { slug: params.slug } }),
  component: BlogPost,
});

function BlogPost() {
  const post = Route.useLoaderData();
  return <article>{post.body}</article>;
}
```
The key difference: TanStack Start uses **server functions** co-located with routes, not Route Handlers. The RPC call is type-safe end-to-end.

### Comparison

| | TanStack Start | Next.js |
|---|---|---|
| Bundler | Vite | Turbopack / Webpack |
| Router | React Router v7 | App Router (custom) |
| Server data | Server functions (RPC) | Server Components + Route Handlers |
| Edge/Cloudflare | Native (V8 Workers) | Workers via `@cloudflare/next-on-pages` (adapter) |
| RSC (React Server Components) | Not supported yet | Full support |
| PPR (Partial Prerendering) | No | Yes (experimental) |
| Ecosystem | Small, growing | Largest in React ecosystem |
| Vercel integration | Manual | First-class |
| TypeScript end-to-end | Yes (server functions) | Via tRPC or similar |

### When to Use TanStack Start
- Deploying to Cloudflare Workers natively (requires V8-compatible runtime)
- Preference for Vite tooling over Webpack/Turbopack
- Already using TanStack Router in an SPA and need to add server functions
- Experimenting with the React Router v7 / Vite stack

### When to Use Next.js (Most Cases)
- Deploying to Vercel, AWS, or any standard Node.js host
- Need RSC or PPR
- Team has existing Next.js expertise
- App requires features from Next.js ecosystem (e.g., NextAuth.js, next-intl, Payload CMS)
- SEO and SSR are priorities

### Shared Concepts
```
File-based routing       → both support it
Loaders/server data      → next: server components; tanstack: loader + server fn
Middleware               → next: middleware.ts; tanstack: createMiddleware
Static assets            → both serve from /public
Environment variables    → both via process.env / import.meta.env
```

## Key Rules
- Default to Next.js for new projects unless there's a specific reason for TanStack Start.
- Choose TanStack Start when Cloudflare Workers runtime is a hard requirement.
- TanStack Start server functions provide end-to-end type safety without tRPC — that's a genuine advantage.
- Next.js `@cloudflare/next-on-pages` adapter works but adds complexity; native TanStack Start on Workers is simpler.
- Neither framework locks you in at the React component level — UI components are portable.
