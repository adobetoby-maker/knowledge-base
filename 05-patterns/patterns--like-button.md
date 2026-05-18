# Pattern: Like / Upvote Button

## Overview

Toggle a like/upvote state with optimistic updates. The like count should update immediately on click without waiting for the server. Undo support within a few seconds (Twitter-style) is expected. Prevent duplicate likes at the DB level, not just in the UI.

## Schema

```sql
CREATE TABLE likes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id),
  target_type TEXT NOT NULL,   -- 'post', 'comment', 'product'
  target_id   UUID NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, target_type, target_id)
);

-- Denormalized count on the target for fast reads
ALTER TABLE posts ADD COLUMN like_count INTEGER NOT NULL DEFAULT 0;

-- Maintain with trigger or in application code
```

## Hook with Optimistic Update

```tsx
function useLike(targetType: string, targetId: string, initialLiked: boolean, initialCount: number) {
  const [liked, setLiked] = useState(initialLiked)
  const [count, setCount] = useState(initialCount)
  const [pending, setPending] = useState(false)
  const debounceRef = useRef<ReturnType<typeof setTimeout>>()

  const toggle = async () => {
    if (pending) return

    // Optimistic update
    const newLiked = !liked
    setLiked(newLiked)
    setCount(c => c + (newLiked ? 1 : -1))

    // Debounce to allow rapid toggle without multiple API calls
    clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(async () => {
      setPending(true)
      try {
        await fetch('/api/likes', {
          method: newLiked ? 'POST' : 'DELETE',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ targetType, targetId }),
        })
      } catch {
        // Revert on error
        setLiked(!newLiked)
        setCount(c => c + (newLiked ? -1 : 1))
      } finally {
        setPending(false)
      }
    }, 300)
  }

  useEffect(() => () => clearTimeout(debounceRef.current), [])

  return { liked, count, toggle, pending }
}
```

## Component

```tsx
export function LikeButton({ targetType, targetId, initialLiked, initialCount }: {
  targetType: string
  targetId: string
  initialLiked: boolean
  initialCount: number
}) {
  const { liked, count, toggle } = useLike(targetType, targetId, initialLiked, initialCount)

  return (
    <button
      onClick={toggle}
      className={cn(
        'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm transition-colors',
        liked
          ? 'bg-red-50 text-red-600 hover:bg-red-100'
          : 'text-gray-500 hover:bg-gray-100'
      )}
      aria-pressed={liked}
      aria-label={liked ? 'Unlike' : 'Like'}
    >
      <HeartIcon
        className={cn('w-4 h-4 transition-transform', liked && 'scale-110 fill-current')}
      />
      <span className="tabular-nums">{formatCount(count)}</span>
    </button>
  )
}
```

## API Route

```ts
// app/api/likes/route.ts
export async function POST(req: Request) {
  const user = await requireAuth(req)
  const { targetType, targetId } = await req.json()

  try {
    await db.transaction(async (tx) => {
      await tx.insert(likes).values({ userId: user.id, targetType, targetId })
      // Increment denormalized count
      await tx.execute(sql`
        UPDATE ${sql.identifier(targetType + 's')}
        SET like_count = like_count + 1
        WHERE id = ${targetId}
      `)
    })
  } catch (err) {
    if (isUniqueConstraintError(err)) {
      return Response.json({ error: 'Already liked' }, { status: 409 })
    }
    throw err
  }

  return Response.json({ success: true })
}

export async function DELETE(req: Request) {
  const user = await requireAuth(req)
  const { targetType, targetId } = await req.json()

  const deleted = await db.delete(likes)
    .where(and(
      eq(likes.userId, user.id),
      eq(likes.targetType, targetType),
      eq(likes.targetId, targetId),
    ))
    .returning()

  if (deleted.length > 0) {
    await db.execute(sql`
      UPDATE ${sql.identifier(targetType + 's')}
      SET like_count = GREATEST(0, like_count - 1)
      WHERE id = ${targetId}
    `)
  }

  return Response.json({ success: true })
}
```

## Key Rules

- The `UNIQUE(user_id, target_type, target_id)` constraint prevents double-likes at the DB level — the API can return 409 on conflict.
- Debounce the API call (300ms) to allow rapid toggle without two round trips.
- `GREATEST(0, like_count - 1)` prevents the count going negative due to race conditions.
- `aria-pressed` makes the button accessible — screen readers announce "Like button, pressed" or "Like button, not pressed".
- `tabular-nums` prevents layout shift as the number changes between "99" and "100".
