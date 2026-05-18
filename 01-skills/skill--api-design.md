# Skill: api-design

**Trigger:** Designing or implementing REST API routes — Route Handlers in Next.js App Router, Cloudflare Workers fetch handlers, or standalone Express/Hono APIs.
**Returns:** URL structure, HTTP verb selection, request/response schemas, error handling, auth patterns.

## HTTP Verb Semantics

| Verb | Semantics | Idempotent | Has Body |
|------|-----------|------------|----------|
| GET | Read, no side effects | Yes | No |
| POST | Create or trigger action | No | Yes |
| PUT | Replace entire resource | Yes | Yes |
| PATCH | Partial update | No | Yes |
| DELETE | Remove resource | Yes | No |

Use the correct verb. A GET request that modifies state is a serious bug (violates HTTP caching and safety assumptions).

## URL Structure

```
Collection: /api/invoices          (GET list, POST create)
Item:        /api/invoices/:id     (GET, PUT, PATCH, DELETE)
Nested:      /api/invoices/:id/line-items  (related resource)
Action:      /api/invoices/:id/send  (non-CRUD action, POST)
```

Naming rules:
- Plural nouns for resources (`/invoices` not `/invoice`)
- Lowercase, hyphen-separated (`/line-items` not `/lineItems`)
- No verbs in URLs (`/invoices/:id/send` not `/sendInvoice/:id`)

## Next.js Route Handler Pattern

```typescript
// app/api/invoices/[id]/route.ts
import { NextRequest } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  
  // Auth
  const supabase = createServerClient(/* ... */)
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 })
  
  // Fetch
  const { data, error } = await supabase
    .from('invoices')
    .select('*')
    .eq('id', id)
    .eq('user_id', user.id)  // RLS + explicit scope
    .single()
  
  if (error?.code === 'PGRST116') return Response.json({ error: 'Not found' }, { status: 404 })
  if (error) return Response.json({ error: 'Server error' }, { status: 500 })
  
  return Response.json(data)
}
```

## Response Shape Consistency

Pick one shape and use it everywhere:

```typescript
// Success
{ data: T, meta?: { page, total } }

// Error
{ error: string, details?: Record<string, string[]> }

// List
{ data: T[], meta: { page: number, total: number, hasMore: boolean } }
```

Never mix shapes across routes — clients must be able to write generic error handling.

## Status Codes

```
200 OK           — successful GET, PUT, PATCH
201 Created      — successful POST that created a resource
204 No Content   — successful DELETE (no body)
400 Bad Request  — client sent invalid data (validation error)
401 Unauthorized — not authenticated
403 Forbidden    — authenticated but not allowed
404 Not Found    — resource doesn't exist
409 Conflict     — unique constraint violation, duplicate
422 Unprocessable — semantically invalid (valid JSON but business logic rejects it)
500 Internal     — server error (never expose details to client)
```

## Input Validation at the Boundary

```typescript
const CreateInvoiceSchema = z.object({
  amount: z.number().positive(),
  description: z.string().min(1).max(500),
  due_date: z.string().datetime().optional()
})

export async function POST(request: NextRequest) {
  const body = await request.json()
  const result = CreateInvoiceSchema.safeParse(body)
  
  if (!result.success) {
    return Response.json(
      { error: 'Validation failed', details: result.error.flatten().fieldErrors },
      { status: 400 }
    )
  }
  
  // result.data is fully typed and validated
}
```

## Rate Limiting

For public or AI-facing routes, add rate limiting. Using Cloudflare Workers KV:

```typescript
async function checkRateLimit(key: string, env: Env, limit = 10, windowSecs = 60) {
  const current = Number(await env.KV.get(`rate:${key}`) ?? '0')
  if (current >= limit) return false
  
  await env.KV.put(`rate:${key}`, String(current + 1), { expirationTtl: windowSecs })
  return true
}
```

For Next.js, use Upstash Redis or a similar edge-compatible rate limiter.

## API Versioning

For public APIs: version in the URL path (`/api/v1/invoices`). For internal APIs between frontend and backend of the same app: no versioning needed — deploy together.

Do not add versioning prematurely. Add it when you have external consumers whose code you cannot control.
