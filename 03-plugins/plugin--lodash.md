# Plugin: Lodash

## Overview
Lodash provides battle-tested utility functions for data manipulation that would otherwise require verbose, error-prone custom code. The critical import discipline—pulling individual functions rather than the entire library—is non-negotiable in frontend builds where the full lodash bundle adds ~70KB gzipped. The second discipline is knowing which Lodash functions solve a specific problem better than the native equivalent (deep clone, deep equality, chunking, grouping).

## Import Individual Functions — Not the Whole Library
```ts
// WRONG — imports entire ~70KB lodash bundle
import _ from 'lodash';
_.debounce(fn, 300);

// CORRECT — tree-shaken, only the used function is bundled
import debounce from 'lodash/debounce';
import cloneDeep from 'lodash/cloneDeep';
import groupBy from 'lodash/groupBy';
import isEqual from 'lodash/isEqual';
import chunk from 'lodash/chunk';

// Also correct with lodash-es (ESM, better tree-shaking in bundlers that support it)
import { debounce, cloneDeep } from 'lodash-es';
```

## Deep Clone — When Spread Isn't Enough
```ts
import cloneDeep from 'lodash/cloneDeep';

// Spread only copies one level deep
const shallow = { ...original };        // nested objects are still shared references
const deep = cloneDeep(original);       // fully independent copy, all levels

// Primary use cases:
// 1. Redux reducers manipulating nested state without immer
// 2. Passing objects to external APIs that mutate their input
// 3. Storing "original" copies for comparison / cancel operations
const originalConfig = cloneDeep(config);
// ... user edits config ...
if (!isEqual(config, originalConfig)) {
  markDirty();
}
```

## Deep Equality — useEffect Dependency Comparison
```ts
import isEqual from 'lodash/isEqual';

// useEffect with object deps re-runs on every render because {} !== {}
// Solution: compare with isEqual in a custom hook
function useDeepCompareMemo<T>(value: T): T {
  const ref = useRef<T>(value);
  if (!isEqual(ref.current, value)) {
    ref.current = value;
  }
  return ref.current;
}

// Also useful for: change detection, memoized selectors, test assertions
expect(isEqual(result, expected)).toBe(true);
```

## GroupBy — Aggregation Without Reduce Boilerplate
```ts
import groupBy from 'lodash/groupBy';

const orders = [
  { id: 1, status: 'pending', amount: 100 },
  { id: 2, status: 'shipped', amount: 200 },
  { id: 3, status: 'pending', amount: 50 },
];

// Cleaner than a manual reduce
const byStatus = groupBy(orders, 'status');
// { pending: [{...}, {...}], shipped: [{...}] }

// With computed key
const byMonth = groupBy(invoices, (inv) =>
  format(new Date(inv.date), 'yyyy-MM')
);
```

## Chunk — Batch Processing
```ts
import chunk from 'lodash/chunk';

const ids = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

// Process in batches of 3 to avoid overwhelming a DB or API
for (const batch of chunk(ids, 3)) {
  await db.updateMany({ id: { in: batch } }, { processed: true });
}

// Also useful for: pagination display, parallel fetch with concurrency limit
const batchedRequests = chunk(urls, 5);
for (const batch of batchedRequests) {
  await Promise.all(batch.map(url => fetch(url)));
}
```

## Debounce and Throttle
```ts
import debounce from 'lodash/debounce';
import throttle from 'lodash/throttle';

// Debounce: fires after N ms of silence (search input, autosave)
const debouncedSearch = debounce((query: string) => {
  fetchResults(query);
}, 300);

// Throttle: fires at most once per N ms (scroll handler, resize)
const throttledScroll = throttle(() => {
  updateScrollPosition();
}, 100);

// In React — create once with useMemo, not on every render
const debouncedFetch = useMemo(
  () => debounce((q: string) => fetchResults(q), 300),
  [] // stable reference across renders
);

// Cleanup on unmount
useEffect(() => () => debouncedFetch.cancel(), [debouncedFetch]);
```

## Other Commonly Useful Functions
```ts
import omit from 'lodash/omit';
import pick from 'lodash/pick';
import merge from 'lodash/merge';
import uniqBy from 'lodash/uniqBy';

// Remove sensitive fields before logging or sending to client
const safeUser = omit(user, ['passwordHash', 'resetToken']);

// Deep merge for config objects (unlike Object.assign which is shallow)
const config = merge({}, defaultConfig, userConfig);

// Deduplicate by field
const uniqueUsers = uniqBy(users, 'email');
```

## Key Rules
- **Import per-function** — `import debounce from 'lodash/debounce'`, never `import _ from 'lodash'` in browser code.
- **`cloneDeep` for nested mutable objects** — `{ ...obj }` only clones one level.
- **`isEqual` for deep equality in `useEffect` deps** — `{}` never equals `{}` by reference.
- **`chunk` for batch DB/API operations** — protect downstream services from thundering-herd bulk requests.
- **`debounce` in `useMemo`** — creating a new debounced function every render defeats the debounce.
- **Cancel debounced functions on unmount** — stale closures calling setState after unmount cause warnings.
- **Prefer native where equivalent** — `Array.filter`, `Array.map`, `Array.find` don't need Lodash; use Lodash for operations with no clean native equivalent.
