# Failure: Missing Await

Forgetting `await` on an async call returns a Promise object instead of the resolved value. JavaScript does not throw — it silently uses the Promise where a value was expected. This produces confusing bugs: `[object Promise]` in UI, `undefined` from a destructure, or database writes that appear to succeed but never ran.

## The Core Problem

```ts
// WRONG — user is a Promise, not the resolved user object
const user = fetchUser(id);
const name = user.name; // undefined — Promise has no .name

// RIGHT
const user = await fetchUser(id);
const name = user.name; // works
```

The insidious version is when the unresolved Promise is truthy:

```ts
if (fetchUser(id)) {
  // always true — a Promise object is truthy
}
```

Or when passed to a function that accepts any value:

```ts
await db.insert({ data: serialize(user) }); // if serialize is async and not awaited, inserts "[object Promise]"
```

## TypeScript's `@typescript-eslint/no-floating-promises`

Enable this rule. It catches `async` function calls whose return value (a Promise) is not awaited, `.then()`-chained, or explicitly discarded with `void`.

```json
// .eslintrc
{
  "rules": {
    "@typescript-eslint/no-floating-promises": "error",
    "@typescript-eslint/no-misused-promises": "error"
  }
}
```

`no-misused-promises` catches the boolean-context mistake above — passing a Promise to an `if` condition or a non-async callback.

When you intentionally fire-and-forget, be explicit: `void sendAnalytics(event)`. The `void` operator documents intent and silences the lint rule.

## The async forEach Bug

`Array.prototype.forEach` does not understand async callbacks. It calls each callback and moves on without waiting for the returned Promise to settle:

```ts
// WRONG — all three run concurrently AND forEach returns before they finish
const ids = [1, 2, 3];
ids.forEach(async (id) => {
  await processItem(id); // Promise ignored by forEach
});
// code here runs before any processItem completes
```

Use `for...of` when you need sequential execution:

```ts
for (const id of ids) {
  await processItem(id); // truly sequential
}
```

Use `Promise.all` when parallel execution is fine but you need to wait for all:

```ts
await Promise.all(ids.map((id) => processItem(id)));
```

Never use `forEach` with an async callback unless you genuinely want fire-and-forget with no guarantee of order or completion.

## Promise.all Mistakes

`Promise.all` short-circuits on the first rejection — any error in any promise rejects the whole array. If you need all results regardless of individual failures, use `Promise.allSettled`:

```ts
// WRONG for error tolerance — one failure kills all
const results = await Promise.all(items.map(fetch));

// RIGHT when partial success is acceptable
const results = await Promise.allSettled(items.map(fetch));
const succeeded = results.filter(r => r.status === 'fulfilled').map(r => r.value);
```

Also: `Promise.all` starts all promises simultaneously. If operations have side effects or ordering requirements, use sequential `for...of` instead.

## Async IIFE and Top-Level Await

In older Node.js or CJS modules without top-level `await`, wrapping async entry points in an IIFE is common. A missing `await` inside the IIFE is a silent failure:

```ts
// WRONG — init runs but errors are swallowed
(async () => {
  startServer(); // missing await
})();

// RIGHT
(async () => {
  await startServer();
})().catch(console.error); // also add error handler on the IIFE itself
```

## Key Rules

- Enable `@typescript-eslint/no-floating-promises` and `no-misused-promises` — they catch the majority of missing-await bugs statically.
- Never use `forEach` with an async callback when completion or error handling matters.
- Use `for...of` for sequential async work; `Promise.all` for parallel work where you need all results.
- Use `Promise.allSettled` when some operations may fail and you want partial success.
- Mark intentional fire-and-forget with `void` to distinguish from mistakes.
- When a value comes back as `undefined` or `[object Promise]` unexpectedly, the first suspect is a missing `await`.
