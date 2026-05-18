# Failure: Promise.all Fails Fast on First Rejection

## The Behavior

`Promise.all(promises)` takes an array of promises and resolves when all of them resolve. If **any single promise rejects**, `Promise.all` immediately rejects with that error. The other promises keep running in the background (JavaScript can't cancel them), but their results are discarded. You don't get any results — not even the ones that succeeded.

This is correct and intended behavior for dependent operations where failure of one means the rest are meaningless. It is wrong for independent operations where each one should complete regardless of the others.

```typescript
// If fetchUser fails, fetchPosts and fetchComments results are thrown away
const [user, posts, comments] = await Promise.all([
  fetchUser(userId),      // ← this fails
  fetchPosts(userId),     // ← this succeeds but result is discarded
  fetchComments(userId),  // ← this succeeds but result is discarded
]);
// Only the error is surfaced
```

## When Promise.all Is Wrong

Use `Promise.all` when all results are required to proceed and failure of any one is a failure of the whole operation. Example: fetching all the data needed to render a page — if any piece is missing, the page can't render, so failing fast is correct.

Use `Promise.allSettled` when operations are **independent** and you want all of them to complete regardless of individual failures. Examples: sending notifications to multiple users, fetching optional sidebar widgets, running multiple data cleanup jobs.

## Promise.allSettled for Independent Operations

`Promise.allSettled` waits for all promises to either resolve or reject, then returns an array of result objects. Every promise gets a chance to complete. You get full results and handle errors per-item.

```typescript
const results = await Promise.allSettled([
  notifyUser(user1),
  notifyUser(user2),
  notifyUser(user3),
]);

for (const result of results) {
  if (result.status === "fulfilled") {
    console.log("notified:", result.value);
  } else {
    console.error("notification failed:", result.reason);
    // Log, alert on-call, enqueue retry — but don't abort the others
  }
}
```

## Error Aggregation Pattern

For batch operations, collect all errors and surface them together rather than stopping at the first:

```typescript
async function processAll<T>(
  items: T[],
  fn: (item: T) => Promise<void>
): Promise<{ succeeded: number; failed: Array<{ item: T; error: unknown }> }> {
  const results = await Promise.allSettled(items.map(fn));

  const failed = results
    .map((r, i) => ({ result: r, item: items[i] }))
    .filter((x): x is { result: PromiseRejectedResult; item: T } =>
      x.result.status === "rejected"
    )
    .map(({ result, item }) => ({ item, error: result.reason }));

  return { succeeded: results.length - failed.length, failed };
}
```

This pattern is useful for bulk emails, data migrations, batch API calls, and any fan-out operation where partial success is meaningful.

## Promise.any — When You Need One Success

A lesser-used third option: `Promise.any` resolves as soon as **any one** promise resolves. Rejects only if all promises reject. Use this when you're querying multiple sources for the same data and need the first successful response (e.g., querying multiple CDN nodes or fallback API endpoints).

## The Hidden Cost of Discarded Promises

When `Promise.all` rejects and you catch the error, the other promises are still running in the background. If they make mutations — database writes, sending emails — those mutations will complete even though your code thinks the overall operation failed. This can cause partial state changes.

For mutation-heavy workflows, consider cancellation tokens or checking an abort flag in each operation, or use a saga pattern with explicit compensating transactions.

## Key Rules

- **`Promise.all` = fail fast, all-or-nothing** — use when all results are needed and partial failure is total failure.
- **`Promise.allSettled` = complete all, report individually** — use for independent side effects.
- **`Promise.any` = first success wins** — use for redundant data sources.
- **Never assume rejected `Promise.all` means other promises stopped** — they keep running; their side effects still happen.
- **Collect errors with `allSettled` for batch operations** — one bad email address shouldn't block 999 successful sends.
- **Log all `allSettled` rejections** — even if you don't throw, silent partial failures accumulate.
