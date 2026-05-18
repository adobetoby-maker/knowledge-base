# Failure: GraphQL N+1 Query Problem

## Why This Is Worse Than REST N+1

In REST, N+1 usually affects one endpoint at a time. In GraphQL, every field resolver is a discrete function — meaning a single query like `{ users { posts { comments { author { name } } } } }` can fire hundreds of database queries for a handful of rows. The schema's composability is precisely what makes the problem unbounded. A REST endpoint at least has a known data shape; a GraphQL resolver doesn't know its siblings are also hitting the database for the same parent IDs.

The resolver model resolves fields independently. Without batching, `User.posts` fires once per user, `Post.comments` fires once per post, and so on. Depth multiplies linearly.

## DataLoader: The Only Correct Fix

DataLoader batches multiple individual load calls that occur in the same tick into a single batch function call. The key mechanism is the event loop tick boundary — DataLoader collects all `.load(id)` calls made synchronously (or in the same microtask queue flush), then calls the batch function once with the full array of keys.

```ts
import DataLoader from 'dataloader';

// Batch function receives an array of IDs, must return array in same order
const userLoader = new DataLoader<string, User>(async (ids) => {
  const users = await db.user.findMany({ where: { id: { in: [...ids] } } });
  // MUST preserve order — DataLoader maps result[i] to ids[i]
  const map = new Map(users.map(u => [u.id, u]));
  return ids.map(id => map.get(id) ?? new Error(`User ${id} not found`));
});

// In resolver:
const PostResolver = {
  author: (post) => userLoader.load(post.authorId), // batched automatically
};
```

**Order preservation is mandatory.** If the batch function returns results in a different order than the input IDs, DataLoader silently maps wrong data to wrong callers. Always build a map and re-index by input order.

## Per-Request Instantiation

DataLoader caches by default within a loader instance. This is a feature, not a bug — but it means loaders must be created per-request, not as module-level singletons. A singleton loader would leak data across users.

```ts
// WRONG — shared across requests, cache leaks between users
const userLoader = new DataLoader(...);

// RIGHT — created in context factory, one per request
const context = ({ req }) => ({
  loaders: {
    user: new DataLoader(batchUsers),
    post: new DataLoader(batchPosts),
  }
});
```

## Batch Window Size

The default batch window is the next event loop tick. For most applications this is correct. For very high-throughput scenarios where you want to coalesce more aggressively, `batchScheduleFn` can be configured. But widening the window increases latency — don't do it speculatively. The default collects all loads from a single resolver pass, which is the right scope.

## Cache Invalidation Inside a Request

DataLoader's per-request cache is safe for reads but problematic if you mutate and then re-read in the same request. After a mutation, call `loader.clear(id)` or `loader.clearAll()` to evict stale cache entries.

## Detecting N+1 Before It Hits Production

- `graphql-query-complexity` — reject queries above a complexity threshold
- Apollo Server's `tracing` / `plugins` — log resolver timing to spot repeated calls
- Prisma's query logging with `log: ['query']` — count identical queries in a single request

## Key Rules

- Create DataLoader instances per request, never at module scope
- The batch function return array must match input IDs order exactly — use a Map
- Resolvers call `loader.load(id)`, never `db.find(id)` directly for related entities
- Clear loader cache after mutations within the same request
- Set a query complexity limit to cap worst-case resolver depth
- Never widen the batch window without measuring — default tick boundary is correct for most cases
