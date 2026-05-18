# API-First Design

## The Principle

Design the API contract before writing implementation. Agree on request/response shapes, status codes, and error formats in TypeScript types before writing handler code or UI code.

This prevents the most common rework pattern: building UI against assumptions about the API, then discovering the API shape is wrong during integration.

## Start with Types

```typescript
// Before writing any handler or component, define these:

// Request type (what the API accepts):
interface CreateInvoiceRequest {
  customerId: string
  lineItems: Array<{
    description: string
    quantity: number
    unitPriceCents: number
  }>
  dueDateIso: string  // ISO 8601 — no ambiguous date strings
  notes?: string
}

// Response type (what the API returns):
interface CreateInvoiceResponse {
  success: true
  data: {
    id: string
    number: string
    totalCents: number
    status: 'draft' | 'sent' | 'paid' | 'overdue'
    createdAt: string
  }
}

// Error type (consistent across all endpoints):
interface ApiError {
  success: false
  error: {
    code: 'UNAUTHORIZED' | 'NOT_FOUND' | 'VALIDATION_ERROR' | 'INTERNAL_ERROR'
    message: string
    details?: Record<string, string[]>  // field-level validation errors
  }
}

type CreateInvoiceResult = CreateInvoiceResponse | ApiError
```

## Consistent Error Format

Every endpoint must return the same error shape. Client code should only need one error handler:

```typescript
// Consistent across all handlers:
function apiError(code: ApiError['error']['code'], message: string, details?: Record<string, string[]>) {
  return Response.json({ success: false, error: { code, message, details } }, {
    status: code === 'UNAUTHORIZED' ? 401
          : code === 'NOT_FOUND' ? 404
          : code === 'VALIDATION_ERROR' ? 400
          : 500
  })
}

// Client error handler:
async function handleApiResponse<T>(response: Response): Promise<T> {
  const json = await response.json()
  if (!json.success) {
    throw new ApiError(json.error.code, json.error.message, json.error.details)
  }
  return json.data
}
```

## REST URL Conventions

```
GET    /api/invoices              → list (paginated)
POST   /api/invoices              → create
GET    /api/invoices/:id          → read single
PATCH  /api/invoices/:id          → partial update
DELETE /api/invoices/:id          → delete
POST   /api/invoices/:id/send     → action (not a resource mutation)
POST   /api/invoices/:id/payments → sub-resource create
```

Use nouns, not verbs in URLs. Actions (`send`, `archive`, `approve`) go as sub-routes with POST.

## Idempotency

GET, PUT, DELETE: idempotent (calling twice has same result as once).
POST: not idempotent by default.

For POST operations that could be triggered multiple times (form double-submit, webhook retry), add idempotency:

```typescript
// Client sends idempotency key:
const response = await fetch('/api/invoices', {
  method: 'POST',
  headers: {
    'Idempotency-Key': crypto.randomUUID(),  // or derived from form data hash
  },
  body: JSON.stringify(data),
})

// Server checks key before processing:
const idempotencyKey = request.headers.get('Idempotency-Key')
if (idempotencyKey) {
  const existing = await kv.get(`idem:${idempotencyKey}`)
  if (existing) return Response.json(existing)  // return cached result
}
```

## Versioning

Don't version until you need to break a contract. When you do:
- Use URL versioning: `/api/v2/invoices` (simplest, most cacheable)
- Not header versioning — harder to test in browser
- Keep v1 running alongside v2 for migration period

## Document the Contract in Types

Export request/response types from a shared location. Server implements them; client consumes them:

```typescript
// lib/api-types.ts — shared between server handlers and client code
export type { CreateInvoiceRequest, CreateInvoiceResponse, ApiError }
```

When server and client share types from the same file, TypeScript catches mismatches at build time rather than at runtime.
