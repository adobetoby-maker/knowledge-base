# Review: API Contract Checklist

## Overview
An API contract defines what clients can rely on. Inconsistency in naming, status codes, or error
shapes forces every client to handle edge cases differently — and makes the API unpredictable to
integrate. Reviewing against a checklist before merging prevents accumulating technical debt that
becomes expensive to fix once clients are deployed against the API.

## Implementation

### Naming Conventions
```
✓ Resource names are plural nouns:
  GET /users           (not /user, not /getUsers)
  GET /posts/:id
  POST /invoices

✓ No verbs in resource URLs:
  POST /orders/:id/cancel   (not POST /cancelOrder/:id)
  PATCH /subscriptions/:id  (not POST /subscriptions/:id/update)

✓ Nested resources show ownership, not hierarchy:
  GET /users/:userId/orders  — user's orders
  Not: GET /orders?user_id=  (fine too, context-dependent)
```

### HTTP Method Semantics
```
GET    → Read, never modify state
POST   → Create resource (or action with no idempotency)
PUT    → Full replacement of resource (idempotent)
PATCH  → Partial update (idempotent)
DELETE → Remove resource (idempotent)

✓ GET endpoints must be safe (no side effects)
✓ DELETE /users/:id called twice → 2nd call returns 404 (or 204 if idempotent)
✗ POST /users called twice → should NOT create duplicate users if already exists
```

### Status Codes
```
✓ 200 OK          — GET successful
✓ 201 Created     — POST created resource (include Location header)
✓ 204 No Content  — DELETE or action with no body response
✓ 400 Bad Request — validation error (include which fields failed)
✓ 401 Unauthorized — missing or invalid auth token
✓ 403 Forbidden   — authenticated but not allowed
✓ 404 Not Found   — resource doesn't exist (or exists but user can't see it)
✓ 409 Conflict    — duplicate resource, optimistic lock failed
✓ 422 Unprocessable — semantically invalid (business rule violation)
✓ 429 Too Many Requests — rate limit hit (include Retry-After header)
✓ 500 Internal Server Error — should never include internal error details in body

✗ 200 with { success: false } — antipattern
✗ 200 for empty results — use 200 with empty array { "data": [] }
```

### Error Body Schema
```json
{
  "error": {
    "code": "VALIDATION_ERROR",        // machine-readable code (stable, never changes)
    "message": "Validation failed",    // human-readable (can change)
    "details": [
      {
        "field": "email",
        "message": "Email is required",
        "code": "REQUIRED"
      }
    ],
    "request_id": "req_abc123"        // for log correlation
  }
}
```
The error schema must be consistent across ALL endpoints — mixing formats breaks error handling in clients.

### Pagination Format
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 156,
    "total_pages": 8,
    "has_next": true,
    "has_prev": false
  }
}
```
Or cursor-based (preferred for large datasets):
```json
{
  "data": [...],
  "cursor": {
    "next": "eyJpZCI6MTAwfQ==",   // opaque cursor
    "has_more": true
  }
}
```

### Auth and Rate Limit Headers
```
✓ Every mutation endpoint requires auth — no exceptions without explicit justification
✓ Rate limit headers on responses:
  X-RateLimit-Limit: 1000
  X-RateLimit-Remaining: 999
  X-RateLimit-Reset: 1735689600
✓ 429 response includes Retry-After: 60
```

### Versioning Strategy
```
URI versioning (common, visible):   /api/v1/users
Header versioning (cleaner URLs):   Accept: application/vnd.api.v1+json
```
Choose one and apply it consistently. Never break backward compatibility within a version.

## Key Rules
- Resource names must be plural nouns — no verbs, no camelCase in URLs
- 201 Created must include a `Location` header pointing to the new resource URL
- Error responses must always use the same schema — never ad-hoc error strings
- GET requests must never modify state — caches, proxies, and browsers assume they are safe
- Every protected endpoint must reject unauthenticated requests with 401, not 403
- Pagination metadata belongs in the response body, not headers (Link header is less discoverable)
- Version the API from day one — it is much harder to add versioning after clients depend on unversioned URLs
