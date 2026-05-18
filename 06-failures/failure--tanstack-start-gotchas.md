# TanStack Start Common Failures

## 1. Using 'use client' Directive

**Symptom:** Error: `'use client' is not recognized` or unexpected behavior.

**Cause:** TanStack Start is NOT Next.js. The `'use client'` directive is a Next.js convention. TanStack Start has its own client/server boundary pattern.

**Fix:** In TanStack Start, client-only code lives in client-side loaders and components without any special directive. Server code uses server functions.

## 2. Using process.env.NEXT_PUBLIC_* Variables

**Symptom:** Environment variable is `undefined` in browser code.

**Cause:** TanStack Start uses Vite. Browser-exposed variables use the `VITE_` prefix with `import.meta.env`, not `process.env.NEXT_PUBLIC_`.

```typescript
// WRONG (Next.js pattern)
const url = process.env.NEXT_PUBLIC_SUPABASE_URL

// CORRECT (Vite/TanStack Start pattern)
const url = import.meta.env.VITE_SUPABASE_URL
```

**File**: `src/integrations/supabase/client.ts` already handles this with a fallback:
```typescript
const url = import.meta.env.VITE_SUPABASE_URL ?? process.env.VITE_SUPABASE_URL
```

## 3. Route Parameter Syntax

**Symptom:** Route parameter is undefined or the route doesn't match.

**Cause:** TanStack Start uses `$paramName` file naming, not `[paramName]`.

```
// WRONG (Next.js convention)
app/blog/[slug]/page.tsx

// CORRECT (TanStack Start convention)
src/routes/blog/$slug.tsx
```

Access the parameter:
```typescript
// In the route file
import { Route } from './$slug'

export const Route = createFileRoute('/blog/$slug')({
  component: BlogPost,
})

function BlogPost() {
  const { slug } = Route.useParams()
  // ...
}
```

## 4. Server Functions vs Route Handlers

**Symptom:** API endpoint doesn't work or runs on client side.

**Cause:** TanStack Start uses server functions, not Next.js Route Handlers.

```typescript
// WRONG (Next.js pattern — won't work in TanStack Start)
// app/api/tutor/route.ts
export async function POST(req: Request) { ... }

// CORRECT (TanStack Start server function)
// src/routes/api.tutor.ts
import { createAPIFileRoute } from '@tanstack/start/api'

export const Route = createAPIFileRoute('/api/tutor')({
  POST: async ({ request }) => {
    const body = await request.json()
    // server-only code here
    return new Response(JSON.stringify(result))
  },
})
```

## 5. Supabase Client Initialization

**Symptom:** Error during build or module load: "Cannot access 'supabase' before initialization" or missing env var crash.

**Cause:** The Supabase client must use a lazy-proxy pattern to avoid initialization errors when `import.meta.env.VITE_SUPABASE_URL` isn't available during SSR or module loading.

```typescript
// WRONG: direct initialization
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,  // might be undefined during SSR
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY
)

// CORRECT: lazy initialization in src/integrations/supabase/client.ts
let _client: ReturnType<typeof createClient> | null = null

export function getSupabase() {
  if (!_client) {
    _client = createClient(url, key)
  }
  return _client
}
```

## 6. Tab Registry TypeScript Exhaustiveness

**Symptom:** TypeScript error: "Type X is not assignable to type TabKey" or missing tab.

**Cause:** The tab system in `language-lens-elite` uses a TypeScript `Record<TabKey, ComponentType>` — exhaustive. Adding a tab in one place but not the other causes a type error.

**Fix**: Adding a new tab requires BOTH:
1. Add to `TabKey` union in `src/state/app-state.tsx`
2. Add to `TAB_COMPONENTS` in `src/components/tab-registry.ts`

Missing either one produces a TypeScript compile error.

## 7. Cloudflare Workers Runtime Limitations

**Symptom:** Build succeeds but deployed Worker throws at runtime.

**Cause:** The Vite dev server (used with `npm run dev`) uses the Cloudflare Workers runtime via `@cloudflare/vite-plugin`. Some Node.js APIs that work locally are unavailable in production Workers.

Not available:
- `fs`, `path`, `os`, `crypto` (Node.js versions — use Web Crypto API)
- Dynamic `require()`
- `process.cwd()`

Available:
- `fetch`, `Response`, `Request`
- `crypto.subtle` (Web Crypto)
- `TextEncoder`, `URL`

**Debug**: The Cloudflare Workers local emulator (`wrangler dev`) replicates the production environment more accurately than `npm run dev`.
