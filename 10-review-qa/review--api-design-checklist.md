# API Design Review Checklist

## Route Handler Design

- [ ] Route is in `app/api/[path]/route.ts` (not in `pages/api/`)
- [ ] HTTP method matches the operation: GET=read, POST=create, PUT=replace, PATCH=update, DELETE=remove
- [ ] Non-mutating operations use GET (safe and cacheable)
- [ ] POST/PUT/PATCH request body parsed and validated with Zod before use
- [ ] Auth checked before any DB operation

## Request Validation

```typescript
// Every mutation route should follow this pattern:
export async function POST(req: NextRequest) {
  // 1. Auth
  const user = await getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  
  // 2. Parse + validate body
  const body = await req.json()
  const result = schema.safeParse(body)
  if (!result.success) {
    return NextResponse.json({ error: result.error.flatten() }, { status: 400 })
  }
  
  // 3. Business logic
  const data = await processRequest(result.data, user.id)
  
  // 4. Response
  return NextResponse.json(data, { status: 201 })
}
```

## Response Shapes

- [ ] Success responses have consistent shape: `{ data: ... }` or direct object
- [ ] Error responses have consistent shape: `{ error: string }` or `{ error: string, details: ... }`
- [ ] Correct HTTP status codes used (200, 201, 400, 401, 403, 404, 409, 422, 500)
- [ ] No 200 response with error info in the body — use proper status codes

## Status Code Quick Reference

| Code | Meaning | When to use |
|---|---|---|
| 200 | OK | Successful GET, PUT, PATCH |
| 201 | Created | Successful POST that creates a resource |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Invalid input, validation failure |
| 401 | Unauthorized | Not authenticated |
| 403 | Forbidden | Authenticated but not authorized |
| 404 | Not Found | Resource doesn't exist (or access denied) |
| 409 | Conflict | Duplicate, version conflict |
| 422 | Unprocessable | Semantically invalid (not format error) |
| 500 | Server Error | Unexpected failure |

## Webhook Endpoint Specifics

- [ ] Uses Route Handler (not Server Action)
- [ ] Reads raw body via `req.text()` BEFORE parsing (needed for HMAC)
- [ ] Verifies HMAC signature before processing payload
- [ ] Returns 200 immediately — async processing with `waitUntil` or queue
- [ ] Idempotent: re-running with same event ID produces same result

## Cron Endpoint Specifics

- [ ] Verifies `CRON_SECRET` from Authorization header
- [ ] Returns 200 quickly — long jobs run async
- [ ] Has timeout protection (Vercel functions: 60s max, Pro: 300s)

## Pagination

- [ ] Large collections return paginated responses
- [ ] Response includes `count` or `hasMore` for client to know if more exists
- [ ] Page/offset params validated (no negative pages, max page size enforced)

```typescript
// Consistent pagination response:
return NextResponse.json({
  data: records,
  pagination: {
    page: page,
    pageSize: 20,
    total: count,
    hasMore: page * 20 < count,
  }
})
```

## Public vs Private Endpoints

- [ ] Public endpoints (no auth) have rate limiting
- [ ] Internal endpoints (admin/portal) check auth
- [ ] Service-to-service endpoints verify shared secret
- [ ] No endpoint accidentally left open due to missing auth check

## Error Handling

- [ ] All unhandled exceptions return 500 (not crash the function)
- [ ] Error response never includes stack traces or DB error text
- [ ] Errors logged server-side with full context

```typescript
try {
  // business logic
} catch (error) {
  console.error('[/api/invoices POST]', error)
  return NextResponse.json({ error: 'Failed to create invoice' }, { status: 500 })
}
```
