# failure--nextjs-cache-bugs.md

The Next.js App Router has four overlapping cache layers: the Router Cache (client-side), the Full Route Cache (static pages at build), the Data Cache (fetch memoization), and Request Memoization (per-request dedup). Each has different invalidation rules. Getting one wrong means stale data surfaces in production while everything looks correct in dev (where the Data Cache is disabled by default).

## Why Mutations Don't Automatically Invalidate

`fetch()` in Server Components caches responses by default with `force-cache`. A mutation in a Route Handler that changes the underlying data does not automatically bust the fetch cache for the pages that display that data. The pages continue serving the cached response.

The fix requires explicit invalidation. There are two mechanisms:

**`revalidatePath`** — invalidates all cached data for a specific path. Call it server-side after a mutation:

```ts
import { revalidatePath } from 'next/cache';

// In a Server Action or Route Handler:
await db.update(...);
revalidatePath('/products'); // invalidates /products and its layouts
```

**`revalidateTag`** — invalidates all fetches tagged with a specific string. More surgical than path-based:

```ts
// Tag the fetch when fetching:
fetch('/api/products', { next: { tags: ['products'] } });

// After mutation, invalidate by tag:
revalidateTag('products'); // busts all fetches with this tag, across all paths
```

## revalidatePath Scope Gotcha

`revalidatePath('/products')` invalidates the exact path `/products`. It does **not** automatically invalidate `/products/[id]` sub-pages or shared layouts above `/products`. If a layout fetches data that the mutation affects, invalidate the layout path separately, or use `revalidatePath('/', 'layout')` to bust all layouts (heavy-handed but complete).

For a list page at `/products` and detail pages at `/products/[id]`, a product update requires:
```ts
revalidatePath(`/products/${id}`);  // the specific detail page
revalidatePath('/products');         // the list page
```

## Disabling Cache for Specific Fetches

Some fetches should never cache — user-specific data, real-time prices, anything that must always be fresh:

```ts
fetch('/api/cart', { cache: 'no-store' });
// or
fetch('/api/cart', { next: { revalidate: 0 } });
```

In a Server Component, marking a function as `dynamic` forces the entire route to be dynamic and skips the Full Route Cache, but it's coarser than per-fetch `no-store`.

## The Router Cache Problem

Even after `revalidatePath` invalidates the Data Cache on the server, the client-side Router Cache holds a cached version of the page for 30 seconds (navigations) or 5 minutes (prefetches). This means a user who just triggered a mutation may still see stale data if they navigate away and back within that window.

To invalidate the Router Cache after a mutation, call `router.refresh()` on the client. This re-fetches the current page's RSC payload without a full navigation:

```ts
'use client';
import { useRouter } from 'next/navigation';

const router = useRouter();
// After mutation completes:
router.refresh();
```

Calling `revalidatePath`/`revalidateTag` on the server does not clear the client Router Cache — `router.refresh()` is required to push the server-invalidation through to the current client view.

## Key Rules

- `fetch()` caches by default in App Router — always opt out explicitly for user-specific or real-time data with `cache: 'no-store'`.
- `revalidatePath` only invalidates the exact path — invalidate sub-pages and layouts separately.
- `revalidateTag` is more precise than `revalidatePath` for data shared across many pages.
- Server-side cache invalidation does not clear the client Router Cache — call `router.refresh()` to force the client to re-fetch.
- The Data Cache is disabled in development; cache bugs only appear in production builds.
