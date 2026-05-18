# Principle: API Design Ergonomics

## Overview
An ergonomic API is one where a new engineer can guess the correct endpoint, method, and parameters without reading documentation. Poor ergonomics create bugs (wrong status code treated as success), developer frustration (three hours reading docs to POST a simple resource), and inconsistent client code across a codebase. The measure of API quality is not just "does it work" but "can an experienced developer use it correctly on the first try."

## URL Design

**Plural nouns for resources, kebab-case:**
```
GET    /users              → list users
GET    /users/:id          → get one user
POST   /users              → create user
PATCH  /users/:id          → update user (partial)
PUT    /users/:id          → replace user (full)
DELETE /users/:id          → delete user

GET    /users/:id/orders   → orders belonging to a user
```

**No RPC-style verbs in REST URLs:**
```
# Wrong — RPC-style
POST /createUser
POST /getOrdersByUser
POST /cancelOrder

# Right — RESTful
POST   /users
GET    /users/:id/orders
DELETE /orders/:id         (or PATCH /orders/:id with { status: "cancelled" })
```

**Versioning in the URL path (not headers for REST):**
```
/api/v1/users
/api/v2/users   ← breaking changes get a new version
```

## Status Codes — Use Them Correctly

| Code | Meaning | Common mistakes |
|---|---|---|
| 200 | OK — successful GET, PATCH, DELETE | Using 200 for errors with `{ success: false }` |
| 201 | Created — successful POST that created a resource | Returning 200 for POST that created |
| 204 | No Content — DELETE success, no body | Returning 200 with empty body |
| 400 | Bad Request — client-side input error | Using 500 for validation failures |
| 401 | Unauthorized — not authenticated | Confusing with 403 |
| 403 | Forbidden — authenticated but not allowed | Using 404 to hide resource existence |
| 404 | Not Found | Using 400 for missing resources |
| 409 | Conflict — resource already exists, duplicate key | Using 400 for conflicts |
| 422 | Unprocessable Entity — validation failed | Acceptable alternative to 400 for validation |
| 429 | Too Many Requests — rate limited | |
| 500 | Internal Server Error — unexpected server failure | Returning 500 for predictable errors |

**Never return 200 with an error payload:**
```typescript
// Wrong: every client must check response body for errors
res.status(200).json({ success: false, error: "User not found" });

// Right: HTTP status IS the error signal
res.status(404).json({ error: "User not found", code: "USER_NOT_FOUND" });
```

## Consistent Error Shape

Every error response has the same structure — clients write one error handler:
```json
{
  "error": "Validation failed",
  "code": "VALIDATION_ERROR",
  "details": [
    { "field": "email", "message": "Invalid email format" },
    { "field": "name", "message": "Required" }
  ],
  "requestId": "req_abc123"
}
```

## Pagination on Every List Endpoint

No endpoint returns an unbounded list. Cursor-based pagination is preferred for large datasets:
```
GET /orders?limit=20&cursor=eyJpZCI6...
→ { data: [...], nextCursor: "eyJpZCI6...", hasMore: true }
```

Offset-based is simpler but has race condition problems (items added/removed shift pages):
```
GET /orders?page=2&limit=20
→ { data: [...], total: 450, page: 2, totalPages: 23 }
```

## Filtering and Sorting

```
GET /orders?status=pending&sort=-createdAt&limit=20
```

Standard conventions: `-field` means descending, `field` means ascending. Multiple filters are AND by default.

## Key Rules
- Plural nouns, kebab-case, no verbs in URLs
- HTTP method is the verb: GET=read, POST=create, PATCH=partial update, PUT=replace, DELETE=remove
- Status codes carry meaning — 4xx is client error, 5xx is server error, never 200 for errors
- Consistent error shape with `error`, `code`, and optional `details`
- Every list endpoint is paginated with explicit `limit` param and a maximum (e.g., max 100)
- `requestId` in every response for traceability
- Timestamps in ISO 8601 UTC: `2024-03-15T14:32:00Z`
- Filter, sort, and pagination via query parameters — never in the request body for GETs
