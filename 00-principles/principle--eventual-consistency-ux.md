# Principle: Eventual Consistency UX

## Overview
Eventual consistency means different parts of your system may briefly disagree about the current state. This is a deliberate trade-off for availability and performance. The UX failure mode is showing users state that is inconsistent without telling them — users see a stale count, a missing item, or a status that flickers. The right approach is to design the UI to handle the consistency model honestly: use optimistic updates, tell users when state is in-flight, and provide deterministic feedback for the user who just made a change.

## Key Points

### The Problem: Stale State Presented as Definitive
```
User submits order → Order service processes → Analytics service updates → Email service sends
       ↓
User immediately navigates to "My Orders" page
→ Reads from read replica (500ms behind)
→ Shows old list without new order
→ User thinks order failed and submits again
```
The order succeeded — the read was stale. Presenting stale data without context causes duplicate actions and support tickets.

### Optimistic Updates: Best UX
Update the UI immediately, without waiting for server confirmation:
```ts
const addToCart = useMutation({
  mutationFn: (item) => api.cart.add(item),

  // Update UI instantly — don't wait for server
  onMutate: async (newItem) => {
    await queryClient.cancelQueries({ queryKey: ['cart'] });
    const previousCart = queryClient.getQueryData(['cart']);

    queryClient.setQueryData(['cart'], (old) => ({
      ...old,
      items: [...old.items, newItem],
    }));

    return { previousCart }; // stored for rollback
  },

  // If server fails, revert to previous state
  onError: (err, newItem, context) => {
    queryClient.setQueryData(['cart'], context.previousCart);
    toast.error('Failed to add item. Please try again.');
  },

  // Sync with server state on success
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['cart'] });
  },
});
```

The user sees the item added immediately. If it fails, it visually disappears with an error. No spinner, no delay.

### Read-Your-Writes Consistency
The user who performs an action should see their change reflected immediately, even in an eventually consistent system. Approaches:

1. **Route the writer to read their own write:**
   After a POST, redirect to a page that reads from primary (not replica) using a "strong read" token
   
2. **Include the change in the response:**
   The mutation response returns the full updated object; cache it locally rather than re-fetching
   
3. **Sticky sessions to primary:**
   After a write, route all reads for that session to the primary for a short window (dirty approach, but effective)

### "Your Changes Are Saving" > Spinners
```tsx
// Bad: block the user until saved
<button disabled={isSaving}>
  {isSaving ? <Spinner /> : 'Save'}
</button>

// Good: save in background, unblock the user
<div className="flex items-center gap-2">
  <input value={title} onChange={e => setTitle(e.target.value)} />
  {saveStatus === 'saving' && <span className="text-xs text-muted">Saving...</span>}
  {saveStatus === 'saved'  && <span className="text-xs text-green-500">Saved</span>}
  {saveStatus === 'error'  && <span className="text-xs text-red-500">Failed to save</span>}
</div>
```

Google Docs style: the user keeps typing, the save happens in the background, the status is ambient.

### When Eventual Consistency Is Visible

Not all stale data matters equally:
- **Critical to be current:** inventory levels (overselling is bad), account balances, payment status
- **Acceptable to be slightly stale:** view counts, like counts, leaderboard rankings, analytics dashboards
- **Must be immediate for the writer:** the user's own submitted form, their own order, their own profile change

Design the UI around which data is in which category.

### Conflict Resolution Strategy
When two users edit the same record concurrently:
- **Last-write-wins:** simplest, but the first writer loses silently — bad for collaborative editing
- **Optimistic locking:** include a version/etag in the update; fail if version has changed since read
- **CRDTs or OT:** complex but enables true concurrent editing (like Google Docs)
- **Locking:** serialize writes but hurts availability under contention

## Key Rules
- Never show stale data as if it were current state without any indicator
- Implement optimistic updates with rollback for all user-initiated writes (cart, likes, follows, form submissions)
- The user who just wrote must see their own write immediately — design read-your-writes into the critical paths
- "Saving..." feedback unblocks the user; spinners that disable the UI should be used only for truly blocking operations
- Distinguish what data must be strongly consistent (payments) vs. what can be eventually consistent (analytics)
- Conflict resolution strategy must be chosen before building the feature, not discovered when users report lost data
