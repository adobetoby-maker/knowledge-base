# Principle: Eventual Consistency

## What It Is

Eventual consistency: a distributed system guarantees that, given no new updates, all replicas will converge to the same value — eventually. It does NOT guarantee that a read immediately after a write sees that write. The trade-off is availability and partition tolerance (CAP theorem) at the cost of momentary inconsistency.

## When Your App Is Already Eventually Consistent

Most apps are eventually consistent even without realizing it:

- **CDN cache**: a content change is visible on origin immediately but CDN edges may serve stale content for minutes.
- **Read replicas**: writes go to primary, reads go to replica — replica lag means reads can be stale by seconds.
- **Supabase Realtime**: database change is committed, then broadcast via WebSocket — subscriber sees it milliseconds later.
- **Email delivery**: "user created" event fires, welcome email sends asynchronously — user may receive the email 30 seconds later.

## Designing for It

### Optimistic Updates

Show the expected state immediately, correct if the server disagrees:

```ts
// Assume the like succeeds; revert on error
function toggleLike(postId: string) {
  setLiked(prev => !prev)  // Immediate UI update
  setLikeCount(prev => liked ? prev - 1 : prev + 1)

  fetch(`/api/posts/${postId}/like`, { method: 'POST' })
    .catch(() => {
      // Revert on failure
      setLiked(liked)
      setLikeCount(likeCount)
      showToast('Like failed — please retry')
    })
}
```

### Idempotent Writes

Operations that may be retried or delivered twice must produce the same result:

```ts
// Idempotent: second call with same orderId is a no-op
async function createOrder(orderId: string, data: OrderData) {
  await db.insert(orders).values({ id: orderId, ...data })
    .onConflictDoNothing()  // Already exists = already processed
}
```

### Conflict Resolution Strategy

For collaborative editing, define merge strategy upfront:

- **Last write wins**: simple, loses concurrent edits
- **CRDT (Conflict-free Replicated Data Type)**: always merge, no conflicts
- **Operational transform**: complex, used in Google Docs

For most apps, last-write-wins with `updatedAt` timestamp is sufficient.

## Read-After-Write Consistency

When a user submits a form and is redirected to a list view, they expect to see their new record. But if reads go to a replica with 500ms lag, they won't.

Solutions:

1. **Route post-write reads to primary** for a short window:
   ```ts
   const db = justWrote ? primaryDb : replicaDb
   ```

2. **Include the new record in the redirect** rather than refetching:
   ```ts
   const newPost = await createPost(data)
   redirect(`/posts/${newPost.id}`)  // Load from URL — data comes from redirect, not list query
   ```

3. **Optimistic update** in the UI (see above) — show before server confirms.

## Bounded Staleness

Make the acceptable staleness window explicit:

```ts
// Analytics data: 5 minutes stale is fine
const stats = await getCachedStats({ maxAgeMs: 5 * 60 * 1000 })

// Inventory count: 30 seconds stale is acceptable
const stock = await getCachedInventory({ maxAgeMs: 30 * 1000 })

// Cart total: must be fresh
const cart = await db.query.carts.findFirst({ where: ... })  // No cache
```

## Key Rules

- Document the expected consistency level for each operation — don't leave it implicit.
- Read replicas introduce propagation delay — don't assume immediate consistency for critical reads.
- Use optimistic UI for operations the user initiated — it makes the product feel fast.
- Idempotency keys protect against double-processing in eventually-consistent queues.
- "Stale data is fine" — be explicit about where it's acceptable. It usually is for read-heavy views like dashboards.
