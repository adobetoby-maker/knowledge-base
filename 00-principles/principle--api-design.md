# REST API Design Principles

A well-designed REST API is predictable. Developers who learn one endpoint should be able to guess the others. Consistency matters more than cleverness; the goal is an API that requires minimal documentation because it behaves exactly as expected.

## Resource Naming: Plural Nouns

Resources are nouns, not verbs. `/users`, `/orders`, `/invoices` — not `/getUser`, `/createOrder`, `/processInvoice`. Verbs belong in HTTP methods, not URLs.

Use plural nouns consistently. `/users/123` is the canonical form; `/user/123` is inconsistent with `/users`. Nested resources reflect ownership: `/users/123/orders` for orders belonging to a user. Avoid nesting deeper than two levels — `/users/123/orders/456/items` is navigable but `/users/123/orders/456/items/789/reviews` becomes unwieldy. At that depth, use a flat resource with filter params.

## Status Code Semantics

Use status codes precisely; don't default everything to 200 or 500.

- `200 OK` — request succeeded, response body contains the result
- `201 Created` — resource was created; include `Location` header pointing to the new resource
- `204 No Content` — succeeded but no body (DELETE, some PATCHes)
- `400 Bad Request` — client sent malformed syntax (unparseable JSON, missing required field structure)
- `401 Unauthorized` — not authenticated (misleading name; it means "who are you?")
- `403 Forbidden` — authenticated but not permitted for this resource
- `404 Not Found` — resource doesn't exist or caller can't know it exists
- `409 Conflict` — state conflict (duplicate creation, optimistic lock failure)
- `422 Unprocessable Entity` — syntax is valid but semantics are wrong (email format invalid, date in the past where future is required). Use 422 for validation errors, not 400.
- `429 Too Many Requests` — rate limited; include `Retry-After` header
- `500 Internal Server Error` — unexpected server failure

The distinction between 400 and 422 matters: 400 means you can't parse the request; 422 means you parsed it but the values are wrong. Client error handling differs.

## Versioning: URL vs Header

**URL versioning** (`/v1/users`): visible, cacheable, easy to test in a browser. The trade-off is that it technically violates REST (the URL should identify a resource, not a version of the API). It is, however, the most widely understood and least surprising approach. Use it for public APIs.

**Header versioning** (`Accept: application/vnd.myapi.v2+json`): cleaner URLs, better for REST purists. The trade-off: harder to test, not visible in browser address bar, easy to forget in client requests. More appropriate for internal APIs with controlled clients.

Never do both. Pick one and be consistent. For most applications, URL versioning with `/v1/` prefix is the pragmatic choice.

## Pagination Envelope Design

Always paginate collection endpoints. Returning unbounded results is a latency and memory bomb waiting to go off.

Use a consistent envelope for paginated responses:

```json
{
  "data": [...],
  "pagination": {
    "total": 1847,
    "page": 3,
    "per_page": 20,
    "next_cursor": "eyJpZCI6IDEyMH0="
  }
}
```

Prefer cursor-based pagination over offset/page for large or frequently-updated datasets. Offset pagination has a known problem: if rows are inserted or deleted between requests, pages shift and items are skipped or duplicated. Cursor pagination avoids this.

## Error Body Format

Every error response needs a structured body. Never return a bare string or an empty body for an error.

Minimum required fields:
```json
{
  "code": "VALIDATION_ERROR",
  "message": "Request validation failed",
  "details": [
    { "field": "email", "message": "Invalid email format" },
    { "field": "start_date", "message": "Must be in the future" }
  ]
}
```

`code` is a machine-readable constant the client can branch on. `message` is human-readable for debugging. `details` is an array so multiple field errors can be reported in one response (don't force the client to fix errors one at a time).

## Key Rules

- Resources are plural nouns; verbs belong in HTTP methods
- `201` for creation with `Location` header; `422` for semantic validation errors (not `400`)
- Use `404` when a resource doesn't exist; use `403` when it exists but is forbidden
- Pick URL versioning for public APIs; be consistent
- All collection endpoints must be paginated; prefer cursor pagination for large datasets
- Every error response must have a structured body with machine-readable `code`, human `message`, and field-level `details`
