# Principle: API Pagination Design

## Overview
Offset pagination is simple to implement but breaks when data is live: if rows are inserted between page 1 and page 2, items skip or duplicate. Cursor-based pagination is stable because the cursor encodes position in the actual data, not a row count. Returning `total_count` sounds helpful but is expensive on large tables and rarely necessary for the user experience.

## Implementation / Key Points

### Cursor-Based Pagination (Default Choice)
```ts
// Cursor = base64url(last_id + last_timestamp) — stable across inserts/deletes
function encodeCursor(id: string, timestamp: string): string {
  return Buffer.from(JSON.stringify({ id, timestamp })).toString('base64url');
}

function decodeCursor(cursor: string): { id: string; timestamp: string } {
  return JSON.parse(Buffer.from(cursor, 'base64url').toString());
}

// Query pattern — stable ordering by (timestamp, id) pair
async function getEvents(cursor?: string, limit = 20) {
  let query = db.events.orderBy('created_at', 'desc').addOrderBy('id', 'desc').take(limit + 1);

  if (cursor) {
    const { timestamp, id } = decodeCursor(cursor);
    query = query.where(
      `(created_at, id) < ('${timestamp}', '${id}')`
    );
  }

  const items = await query;
  const hasMore = items.length > limit;
  const page = hasMore ? items.slice(0, limit) : items;
  const nextCursor = hasMore ? encodeCursor(page[page.length - 1].id, page[page.length - 1].createdAt) : null;

  return { items: page, next_cursor: nextCursor };
}
```

### Response Shape
```ts
interface PaginatedResponse<T> {
  data: T[];
  next_cursor: string | null;  // null = last page
  // NO total_count by default — omit unless absolutely required
}
```

### Offset Pagination (When Appropriate)
Use offset pagination only for admin grids where users need to jump to page N:
```ts
// GET /api/admin/users?page=5&per_page=20
interface OffsetPaginationResponse<T> {
  data: T[];
  total_count: number;      // OK here — admin needs to show "Page 5 of 47"
  page: number;
  per_page: number;
  total_pages: number;
}
```
Never use offset pagination on public-facing APIs that receive live data.

### Default and Max Page Sizes
```ts
function parsePaginationParams(query: URLSearchParams) {
  const limit = Math.min(
    Number(query.get('limit') ?? 20),   // default: 20
    100                                   // max: 100 — protect against large fetches
  );
  const cursor = query.get('cursor') ?? undefined;
  return { limit, cursor };
}
```

### total_count: Only When Cheap
```ts
// Only include total_count if it's backed by a fast COUNT(*) with a good index
// On tables with millions of rows, COUNT(*) without a good WHERE clause is slow

// Pattern: omit total_count from paginated responses by default
// Add it as an optional parameter: ?include_total=true
// Cache the count for 60 seconds to avoid repeated expensive queries
```

### Signaling Last Page
```
next_cursor: "abc123..."   → more items available
next_cursor: null          → this is the last page
```
Never use an empty array as the last-page signal — clients need to check `next_cursor`, not the data length (edge case: last page has exactly `limit` items).

### Cursor Opacity
The cursor must be treated as an opaque string by API clients:
```
Bad:  GET /events?after_id=uuid-123&after_ts=2024-03-15T10:00:00Z (parsed by client)
Good: GET /events?cursor=eyJpZCI6InV1aWQtMTIzIn0  (opaque, cannot be constructed by client)
```
If the cursor format is transparent, clients start constructing cursors — and then you can never change the format.

## Key Rules
- Use cursor-based pagination for all live-data APIs — it is stable across inserts and deletes.
- Use offset pagination only for admin grids that require jumping to a specific page.
- Default page size = 20; max = 100; enforce both server-side.
- `next_cursor: null` signals last page — never use empty data array as the signal.
- Cursor must be opaque — clients must not be able to construct or parse them.
- Omit `total_count` by default; only include it when the query is fast and the UI genuinely needs it.
- Cursor encodes `(timestamp, id)` pair — timestamp alone causes ties that break ordering.
