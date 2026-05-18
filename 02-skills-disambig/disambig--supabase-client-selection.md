# Disambiguation: Which Supabase Client?

## The Three Clients

Projects using Supabase have three client files, each for a different context. Using the wrong one causes subtle bugs or security vulnerabilities.

| File | Context | Auth | Use When |
|------|---------|------|----------|
| `lib/supabase/client.ts` | Browser | User JWT | Client Components, browser event handlers |
| `lib/supabase/server.ts` | Server | User JWT | Server Components, Route Handlers, middleware |
| `lib/supabase/admin.ts` | Server only | Service role | Admin operations, background jobs, webhooks |

## Browser Client

```typescript
// lib/supabase/client.ts
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
```

**Use when:** The code runs in the browser. Client Components that need to interact with Supabase directly.

**RLS behavior:** Runs under the authenticated user's JWT. RLS policies apply.

## Server Client

```typescript
// lib/supabase/server.ts
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createClient() {
  const cookieStore = await cookies()
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get: (name) => cookieStore.get(name)?.value,
        // ... set/remove handlers
      }
    }
  )
}
```

**Use when:** Server Components, Route Handlers (`app/api/*`), Server Actions. Any server-side code that should respect the current user's permissions.

**RLS behavior:** Runs under the authenticated user's JWT. RLS policies apply. Returns user data correctly, blocks unauthorized access correctly.

## Admin Client (Service Role)

```typescript
// lib/supabase/admin.ts
import { createClient } from '@supabase/supabase-js'

export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!  // NOT NEXT_PUBLIC_
)
```

**Use when:** Administrative operations that must bypass RLS — webhook handlers, background jobs, seeding scripts, admin dashboard queries that need cross-user data access.

**RLS behavior:** BYPASSES ALL RLS POLICIES. Every row in every table is accessible and writable.

**NEVER import in:** Client Components, any file that can be bundled for browser delivery. The service role key gives unrestricted database access to anyone who has it.

## Decision Flow

```
Is this code in a Client Component?
  YES → browser client (lib/supabase/client.ts)
  NO → Is this code accessing data that needs RLS?
    YES → server client (lib/supabase/server.ts)
    NO → Is this an admin/background operation that needs all rows?
      YES → admin client (lib/supabase/admin.ts)
      NO → still use server client (let RLS do its job)
```

## Common Mistakes

**Mistake:** Using admin client in a Route Handler that handles user requests.
**Consequence:** RLS is bypassed — any user can see and modify any other user's data.

**Mistake:** Using browser client in a Server Component.
**Consequence:** Runtime error — `localStorage` doesn't exist on the server.

**Mistake:** Using `NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY` as an env var name.
**Consequence:** Service role key is exposed in the JavaScript bundle — catastrophic security breach.

**Mistake:** Forgetting to await the server client factory function.
**Consequence:** TypeScript may not catch this; the client will be a Promise, and all queries will fail silently.

```typescript
// Wrong — forgot await
const supabase = createClient()  // returns Promise<SupabaseClient>

// Right
const supabase = await createClient()  // returns SupabaseClient
```
