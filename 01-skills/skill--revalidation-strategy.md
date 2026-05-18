# Skill: Next.js Cache Revalidation Strategy

## Overview
Next.js has four distinct caching layers, and revalidation must target the right layer. Using `revalidatePath` when you need `revalidateTag` results in over-revalidation (too much cache busting); using neither means stale data persists after mutations. The key mental model: tags group related cache entries by data dependency; paths group by URL. Mutations should invalidate by data dependency, not by URL.

## Implementation

### The Four Caches (Brief)
1. **Request Memoization** — deduplicates identical `fetch` calls within one render. Auto-invalidated per request.
2. **Data Cache** — persisted fetch results across requests. Invalidated by `revalidateTag` / `revalidatePath` or time-based TTL.
3. **Full Route Cache** — static HTML/RSC payload. Invalidated by `revalidatePath`.
4. **Router Cache** — client-side prefetched page data. Invalidated by `router.refresh()` or on navigation.

### Tag-Based Revalidation (Preferred for Mutations)
```ts
// When fetching data, tag it
async function getInvoices(userId: string) {
  const res = await fetch(`${API_URL}/invoices?userId=${userId}`, {
    next: {
      tags: [
        `invoices`,             // all invoices
        `user:${userId}:invoices`, // invoices for this specific user
      ],
    },
  });
  return res.json();
}

async function getInvoice(id: string) {
  const res = await fetch(`${API_URL}/invoices/${id}`, {
    next: { tags: [`invoice:${id}`] },
  });
  return res.json();
}

// After mutation, revalidate the relevant tags
import { revalidateTag } from 'next/cache';

// Server Action: update an invoice
async function updateInvoice(id: string, data: UpdateInvoiceInput) {
  await db.invoices.update(data, { where: { id } });

  // Invalidate the specific invoice AND the list
  revalidateTag(`invoice:${id}`);
  revalidateTag(`invoices`);
  // Don't revalidate other users' invoice tags — only what changed
}

// Server Action: delete an invoice
async function deleteInvoice(id: string, userId: string) {
  await db.invoices.delete({ where: { id } });

  revalidateTag(`invoice:${id}`);
  revalidateTag(`user:${userId}:invoices`);
}
```

### Path-Based Revalidation (For Public Pages)
```ts
import { revalidatePath } from 'next/cache';

// After updating a blog post
async function updatePost(slug: string, data: PostData) {
  await db.posts.update(data, { where: { slug } });

  revalidatePath(`/blog/${slug}`);  // the specific post page
  revalidatePath('/blog');          // the listing page
  revalidatePath('/');              // the homepage if it shows recent posts
}
```

### On-Demand Revalidation via API Route
Allows external systems (CMS webhooks, admin tools) to trigger revalidation:

```ts
// GET/POST /api/revalidate?path=/blog/my-post&secret=XXX
export async function POST(req: Request) {
  const { searchParams } = new URL(req.url);
  const secret = searchParams.get('secret');
  const path = searchParams.get('path');
  const tag = searchParams.get('tag');

  if (secret !== process.env.REVALIDATION_SECRET) {
    return Response.json({ error: 'Invalid secret' }, { status: 401 });
  }

  if (path) {
    revalidatePath(path);
    return Response.json({ revalidated: true, path });
  }

  if (tag) {
    revalidateTag(tag);
    return Response.json({ revalidated: true, tag });
  }

  return Response.json({ error: 'path or tag required' }, { status: 400 });
}
```

### Time-Based ISR (Stale-While-Revalidate)
For data that doesn't need instant revalidation — use TTL:

```ts
async function getPublicStats() {
  const res = await fetch(`${API_URL}/stats`, {
    next: {
      revalidate: 3600,  // revalidate every hour
      tags: ['stats'],   // can still be purged on demand
    },
  });
  return res.json();
}
```

### Server Action: Revalidate After Mutation
```tsx
'use server';
import { revalidateTag } from 'next/cache';

export async function createInvoice(formData: FormData) {
  const invoice = await db.invoices.create(parseFormData(formData));

  // Revalidate list; no need to revalidate the new invoice's detail page
  // (it didn't exist before — Router Cache has no entry)
  revalidateTag('invoices');
  revalidateTag(`user:${invoice.userId}:invoices`);

  redirect(`/invoices/${invoice.id}`);
}
```

### Router Cache (Client-Side): Force Refresh
Router Cache is not directly controlled — it expires automatically or is cleared by:
```tsx
'use client';
import { useRouter } from 'next/navigation';

function RefreshButton() {
  const router = useRouter();
  return (
    <button onClick={() => router.refresh()}>
      Refresh
    </button>
  );
}
// router.refresh() re-fetches data for the current route without full navigation
```

## Key Rules
- Prefer `revalidateTag` over `revalidatePath` for mutations — tags are more precise and don't over-invalidate.
- Tag fetch calls at creation time, not revalidation time — you can't add tags retroactively.
- Revalidating a tag only invalidates Data Cache entries with that tag — it does not clear the Router Cache (client-side).
- `revalidatePath` with `'layout'` as the second argument clears all segments under that layout.
- On-demand revalidation endpoint must be protected with a secret — unauthenticated endpoints allow cache DoS.
- `revalidate: 0` disables caching entirely — equivalent to `no-store`. Use for real-time data only.
- Server Actions automatically clear the Router Cache for the current path after completing — no manual `router.refresh()` needed in most cases.
