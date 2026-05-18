# Pattern: Bookmark Toggle

## Overview

A bookmark/save button that toggles state optimistically. The pattern is identical to a like button but semantically different: bookmarks are per-user private saves, not public counts. No count is shown. The button must reflect the current state immediately on click, then reconcile with the server response.

## Database Schema

```sql
CREATE TABLE bookmarks (
  user_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_type text NOT NULL,       -- 'post', 'product', 'recipe', etc.
  item_id   uuid NOT NULL,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, item_type, item_id)
);

CREATE INDEX bookmarks_user_idx ON bookmarks(user_id, item_type);
```

Composite primary key naturally enforces uniqueness — no need for an `ON CONFLICT` clause, inserting a duplicate just fails (or use `ON CONFLICT DO NOTHING` for idempotent upsert).

## API Route

```ts
// POST /api/bookmarks — toggle
export async function POST(req: Request) {
  const session = await getServerSession()
  if (!session) return new Response(null, { status: 401 })

  const { itemType, itemId } = await req.json()

  const existing = await db.query.bookmarks.findFirst({
    where: and(
      eq(bookmarks.userId, session.userId),
      eq(bookmarks.itemType, itemType),
      eq(bookmarks.itemId, itemId),
    ),
  })

  if (existing) {
    await db.delete(bookmarks).where(
      and(
        eq(bookmarks.userId, session.userId),
        eq(bookmarks.itemType, itemType),
        eq(bookmarks.itemId, itemId),
      )
    )
    return Response.json({ bookmarked: false })
  } else {
    await db.insert(bookmarks).values({ userId: session.userId, itemType, itemId })
    return Response.json({ bookmarked: true })
  }
}
```

## Optimistic Toggle Component

```tsx
interface BookmarkButtonProps {
  itemType: string
  itemId: string
  initialBookmarked: boolean
}

export function BookmarkButton({ itemType, itemId, initialBookmarked }: BookmarkButtonProps) {
  const [bookmarked, setBookmarked] = useState(initialBookmarked)
  const [pending, setPending] = useState(false)

  async function toggle() {
    if (pending) return
    // Optimistic update
    setBookmarked(prev => !prev)
    setPending(true)

    try {
      const res = await fetch('/api/bookmarks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ itemType, itemId }),
      })
      if (!res.ok) throw new Error('Failed')
      const { bookmarked: serverState } = await res.json()
      setBookmarked(serverState)  // Reconcile with server truth
    } catch {
      setBookmarked(prev => !prev)  // Rollback on error
    } finally {
      setPending(false)
    }
  }

  return (
    <button
      onClick={toggle}
      aria-label={bookmarked ? 'Remove bookmark' : 'Save'}
      aria-pressed={bookmarked}
      className={`p-2 rounded-full transition-colors ${
        bookmarked ? 'text-blue-600 hover:bg-blue-50' : 'text-gray-400 hover:bg-gray-100'
      }`}
    >
      <BookmarkIcon filled={bookmarked} />
    </button>
  )
}

function BookmarkIcon({ filled }: { filled: boolean }) {
  return (
    <svg viewBox="0 0 24 24" width={20} height={20} fill={filled ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth={2}>
      <path d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
    </svg>
  )
}
```

## Bookmarked Items List

```tsx
// Fetch all bookmarks for a user
async function getBookmarks(userId: string, itemType: string) {
  return db.select({ itemId: bookmarks.itemId, createdAt: bookmarks.createdAt })
    .from(bookmarks)
    .where(and(
      eq(bookmarks.userId, userId),
      eq(bookmarks.itemType, itemType),
    ))
    .orderBy(desc(bookmarks.createdAt))
}

// Check if a set of items are bookmarked (for list pages)
async function getBookmarkSet(userId: string, itemType: string, itemIds: string[]): Promise<Set<string>> {
  const rows = await db.select({ itemId: bookmarks.itemId })
    .from(bookmarks)
    .where(and(
      eq(bookmarks.userId, userId),
      eq(bookmarks.itemType, itemType),
      inArray(bookmarks.itemId, itemIds),
    ))
  return new Set(rows.map(r => r.itemId))
}
```

## Using the Set Check in a List

```tsx
// Server Component pattern
export async function PostList({ posts }: { posts: Post[] }) {
  const session = await getServerSession()
  const bookmarked = session
    ? await getBookmarkSet(session.userId, 'post', posts.map(p => p.id))
    : new Set<string>()

  return posts.map(post => (
    <PostCard
      key={post.id}
      post={post}
      bookmarked={bookmarked.has(post.id)}
    />
  ))
}
```

## Key Rules

- Composite primary key `(user_id, item_type, item_id)` enforces uniqueness at the DB level — no application-level guard needed.
- `item_type` as a string column makes the bookmarks table generic: one table handles posts, products, recipes, jobs, etc. without separate join tables.
- Optimistic update must roll back on error — the `catch` block should restore previous state, not just `setBookmarked(false)`.
- `aria-pressed` is the correct ARIA attribute for a toggle button — it communicates current state to screen readers.
- `pending` guard prevents double-toggle race: if user clicks twice quickly, the second click is ignored until the first resolves.
