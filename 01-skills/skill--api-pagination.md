# API Pagination (Cursor-Based)

Cursor-based pagination is the correct default for production APIs. Offset pagination (`?page=3&limit=20`) is easy to understand but breaks under concurrent writes — items shift when new rows are inserted between pages, causing duplicates and skips. Cursors don't have this problem because they anchor to a specific position in the data.

## How Cursor Pagination Works

A cursor is an opaque token the client receives with each page. It encodes "the position of the last item returned." The next request sends this token back, and the server uses it to fetch items that come after that position.

Opaque means the client should not parse or construct cursors. Base64-encode the internal representation so clients can't accidentally depend on its structure.

## Cursor Construction

The cursor encodes the sort key of the last item in the page — whatever columns you ORDER BY.

If ordering by `created_at DESC, id DESC` (stable tie-breaking):

```ts
// encode
const cursor = Buffer.from(JSON.stringify({
  created_at: lastItem.created_at,
  id: lastItem.id
})).toString('base64url');

// decode
const { created_at, id } = JSON.parse(Buffer.from(cursor, 'base64url').toString());
```

The query for the next page uses a row comparison:

```sql
WHERE (created_at, id) < (:created_at, :id)
ORDER BY created_at DESC, id DESC
LIMIT :limit
```

This is more correct than `WHERE created_at < :created_at` because it handles ties on `created_at` correctly via the secondary sort key.

## `hasNextPage` Detection

Fetch `limit + 1` rows. If you get `limit + 1` results back, there is a next page — return only the first `limit` items to the client and compute the cursor from item `limit` (the last one you return). If you get `limit` or fewer, you're on the last page.

Never use COUNT(*) to detect whether there's a next page. COUNT is expensive and often wrong on large tables.

## Consistent Ordering Requirement

Cursor pagination requires a deterministic sort order. If the sort order is ambiguous, the cursor is meaningless. Always include `id` as a tiebreaker column in the ORDER BY clause. UUID primary keys are fine tiebreakers as long as you generate them with sorted UUIDs (UUIDv7) or add `created_at` as the primary sort.

Never allow `ORDER BY` to vary by request without including a stable secondary key.

## Response Shape

```json
{
  "data": [...],
  "pagination": {
    "nextCursor": "eyJjcmVhdGVkX2F0IjoiMjAyNS0...",
    "hasNextPage": true
  }
}
```

Return `nextCursor: null` and `hasNextPage: false` on the last page. Don't omit the field — clients shouldn't have to check `if (response.pagination?.nextCursor)`.

## Backward Pagination

Backward pagination is harder with cursors. The standard pattern for GraphQL-style connections is to accept both `after` (cursor for next page) and `before` (cursor for previous page), then reverse the ORDER BY direction when `before` is provided and reverse the result set before returning it.

For most REST APIs, skip backward pagination entirely. Support forward-only pagination and let clients re-fetch from the start if they need to go back. Backward pagination adds significant complexity and is rarely needed in practice.

## Key Rules

- Always use cursor-based pagination; offset pagination is wrong for production data
- Encode cursors as base64url; never expose internal sort key format
- Fetch `limit + 1` to detect `hasNextPage`; never use COUNT
- ORDER BY must include a stable tiebreaker (id or created_at + id)
- Return `nextCursor: null` explicitly on the last page — don't omit the field
- Validate cursor format on input; return 400 for malformed cursors, not 500
- Document the cursor as opaque in your API spec to prevent clients from parsing it
