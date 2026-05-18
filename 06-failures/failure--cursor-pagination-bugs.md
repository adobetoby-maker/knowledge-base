# Cursor-Based Pagination Edge Cases

Cursor pagination is the correct approach for large or frequently-updated datasets, but its edge cases are subtle. Offset pagination (`LIMIT 10 OFFSET 30`) is simpler to implement but produces incorrect results when rows are inserted or deleted between pages — items are skipped or duplicated. Cursor pagination avoids this by using a stable positional anchor, but the anchor must be designed carefully.

## Null Cursor for the First Page

The cursor for the first page doesn't exist — there is no "previous last row." The convention: `cursor = null` means "start from the beginning."

```ts
function buildQuery(cursor: string | null, limit: number) {
  if (cursor === null) {
    return db.query(`SELECT * FROM posts ORDER BY created_at DESC, id DESC LIMIT $1`, [limit + 1]);
  }
  const { createdAt, id } = decodeCursor(cursor);
  return db.query(
    `SELECT * FROM posts WHERE (created_at, id) < ($1, $2) ORDER BY created_at DESC, id DESC LIMIT $3`,
    [createdAt, id, limit + 1]
  );
}
```

Always treat a missing or null cursor as "fetch from the start." Never throw an error for a missing cursor — it's a valid state for the first page request.

## Cursor Encoding: Base64 of Sort Key

The cursor encodes the position of the last row returned, specifically its sort key values. Encoding in base64 is conventional — it:
- Makes the cursor opaque (clients can't easily manipulate it)
- Safely handles values with special characters (timestamps, UUIDs with hyphens)
- Signals to API consumers that the cursor is not meant to be interpreted

```ts
function encodeCursor(row: { created_at: Date; id: string }): string {
  return Buffer.from(JSON.stringify({ createdAt: row.created_at.toISOString(), id: row.id })).toString('base64');
}

function decodeCursor(cursor: string): { createdAt: string; id: string } {
  return JSON.parse(Buffer.from(cursor, 'base64').toString('utf8'));
}
```

Validate the decoded cursor on the server — a malformed or tampered cursor should return a 400, not crash the query.

## Tie-Breaking When Sort Field Has Duplicates

The most common cursor pagination bug: sorting by a non-unique field (e.g., `created_at`) without a tie-breaker. Multiple rows can have the same `created_at` timestamp. If the cursor is `WHERE created_at < $last_created_at`, rows with the same timestamp as the cursor row are silently skipped.

Always compose the cursor from two fields: a primary sort field and a tie-breaker that is unique (the row's primary key):

```sql
-- Correct: compound sort key with unique tie-breaker
ORDER BY created_at DESC, id DESC

-- Cursor condition: strict less-than on the compound key
WHERE (created_at, id) < ($cursor_created_at, $cursor_id)
```

This is called a keyset pagination or seek pagination. It is semantically correct for any dataset, including those with many rows sharing the same sort value.

## Detecting End of Results

Fetch `limit + 1` rows. If you get `limit + 1` results, there is a next page — the cursor is built from row `limit` (the last one you'll actually return), and the extra row is discarded. If you get `limit` or fewer results, you're on the last page — return `next_cursor: null`.

```ts
const rows = await query(cursor, limit + 1);
const hasNextPage = rows.length > limit;
const pageRows = hasNextPage ? rows.slice(0, limit) : rows;
const nextCursor = hasNextPage ? encodeCursor(pageRows[pageRows.length - 1]) : null;
```

Never return the extra row in the response.

## Reverse Pagination (Previous Page Cursor)

Implementing "previous page" with cursor pagination requires a second cursor and a query with reversed sort order:

```ts
// To get the previous page, sort in the opposite direction using the first row's key
WHERE (created_at, id) > ($first_row_created_at, $first_row_id)
ORDER BY created_at ASC, id ASC LIMIT $limit
// Then reverse the result set before returning
```

This is complex. Many APIs omit "previous page" entirely and only support forward pagination, relying on clients to cache pages they've visited. For most use cases, forward-only pagination is sufficient and significantly simpler.

If bidirectional pagination is required, return both `next_cursor` and `prev_cursor` in the response envelope, using the first row for `prev_cursor` and the last row for `next_cursor`.

## Key Rules

- `cursor = null` means first page; treat it as a valid request, never an error
- Encode cursors as base64(JSON) to make them opaque and safe for URL transmission
- Always include a unique tie-breaker (primary key) in the sort key to handle duplicate sort values
- Fetch `limit + 1` rows to detect next page without a separate COUNT query; return only `limit` rows
- Validate decoded cursors server-side; return 400 for malformed cursors, don't let them reach the SQL query
- Reverse pagination (previous page) requires a reversed query and result reversal; omit it if not required
