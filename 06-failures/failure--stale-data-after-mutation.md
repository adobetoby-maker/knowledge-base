# Failure: Stale Data After Mutation

## Overview
After a successful mutation (create, update, delete), the UI still shows the old data because the client-side cache hasn't been invalidated. The user sees a confusing inconsistency: they just renamed a project but the old name still appears in the list. This is a near-universal failure mode in apps using React Query, SWR, or Apollo — not a bug in the cache library, but a missing cache invalidation step after mutations.

## Why It Happens

Client-side data-fetching libraries cache responses by query key. A mutation updates the server but the cache is unaware:

```
User renames project "Alpha" → "Beta"
→ PUT /projects/123  { name: "Beta" }
→ Server responds 200 OK
→ Cache still holds: GET /projects → [{ id: 123, name: "Alpha" }]
→ UI renders stale cached data: still shows "Alpha"
```

The cache has no way to know the mutation affected the cached data unless explicitly told.

## React Query: Invalidation After Mutation

```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query';

function RenameProject() {
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ id, name }: { id: string; name: string }) =>
      fetch(`/api/projects/${id}`, {
        method: 'PUT',
        body: JSON.stringify({ name }),
      }).then(r => r.json()),

    onSuccess: (data, variables) => {
      // Option 1: Invalidate the query — triggers a refetch
      queryClient.invalidateQueries({ queryKey: ['projects'] });

      // Option 2: Update cache directly (optimistic, no refetch needed)
      queryClient.setQueryData(['projects'], (old: Project[]) =>
        old.map(p => p.id === variables.id ? { ...p, name: variables.name } : p)
      );
    },
  });
}
```

**Invalidate vs setQueryData:**
- `invalidateQueries`: marks the query stale, triggers a background refetch. Accurate but adds a network request.
- `setQueryData`: directly updates the cache. Instant but assumes you know the full new shape (risk of stale fields from the server).

## Query Key Scoping

The invalidation must match the query key used when fetching:

```typescript
// Fetch used this key:
useQuery({ queryKey: ['projects', { status: 'active' }], ... })

// This invalidation MISSES it (different key):
queryClient.invalidateQueries({ queryKey: ['projects'] });  // too broad? No — this works
// invalidateQueries with a partial key invalidates all matching prefixes

// But this won't match:
queryClient.invalidateQueries({ queryKey: ['project', id] });  // singular vs plural
```

Use consistent, hierarchical query keys and invalidate at the right level of specificity.

## SWR: Revalidation After Mutation

```typescript
import useSWR, { mutate } from 'swr';

function RenameProject({ id }: { id: string }) {
  const { data: projects } = useSWR('/api/projects', fetcher);

  async function handleRename(name: string) {
    await fetch(`/api/projects/${id}`, { method: 'PUT', body: JSON.stringify({ name }) });
    // Trigger revalidation for this key
    mutate('/api/projects');
  }
}
```

## Optimistic Updates

For immediate feedback, update the cache before the server confirms, then revert on failure:

```typescript
const mutation = useMutation({
  mutationFn: updateProject,

  onMutate: async (variables) => {
    // Cancel in-flight queries to avoid overwriting optimistic update
    await queryClient.cancelQueries({ queryKey: ['projects'] });

    // Snapshot previous value for rollback
    const previous = queryClient.getQueryData(['projects']);

    // Optimistically update
    queryClient.setQueryData(['projects'], (old: Project[]) =>
      old.map(p => p.id === variables.id ? { ...p, ...variables } : p)
    );

    return { previous };
  },

  onError: (err, variables, context) => {
    // Rollback to previous on error
    queryClient.setQueryData(['projects'], context?.previous);
  },

  onSettled: () => {
    // Always refetch after mutation to sync with server truth
    queryClient.invalidateQueries({ queryKey: ['projects'] });
  },
});
```

## Supabase Realtime Doesn't Replace Invalidation

Supabase realtime subscriptions update the UI when data changes — but only if the subscription is active and the UI is rendering the subscribed data. Realtime does NOT update React Query or SWR caches. You still need explicit cache invalidation after your own mutations.

## Key Rules
- Every mutation must be followed by cache invalidation or a direct cache update
- Invalidate at the narrowest query key that covers the affected data
- Optimistic updates require a rollback path (`onMutate` + `onError`)
- Always call `invalidateQueries` in `onSettled` (not just `onSuccess`) to handle error cases too
- Supabase realtime is for multi-user sync, not a replacement for post-mutation cache management
- When in doubt, invalidate broadly — stale data is a worse user experience than an extra network request
