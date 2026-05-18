# Optimistic vs Pessimistic UI Updates

## What Each Means

**Optimistic update:** Apply the change to the UI immediately, assume the server will succeed, and roll back only if it fails. The user sees the result before the network round-trip completes.

**Pessimistic update:** Wait for the server to confirm success before updating the UI. The user sees a loading state, then the result.

The choice is a bet on conflict probability. Optimistic UI bets the server will agree with what the client just did. Pessimistic UI hedges against the server disagreeing.

## When to Use Optimistic Updates

**Low conflict, low consequence.** Liking a post, toggling a preference, marking a notification as read, reordering items in a drag-and-drop list — these have an extremely high success rate and a trivial rollback story. The perceived snappiness is worth the complexity.

**Idempotent operations where the client has full context.** If the client already knows the new state (a toggle from false → true) and the server is essentially a persistence layer, optimistic updates are clean. The client is not guessing — it is reporting what it intends.

**No sequential dependencies.** Optimistic updates become a trap when one action depends on the result of another. If the user creates a record and immediately tries to update it, and the create hasn't confirmed yet, the update has no server ID to target.

## When to Use Pessimistic Updates

**Destructive or irreversible actions.** Deleting a record, cancelling a subscription, sending an email, submitting a payment — roll back is either impossible or confusing. Show a spinner; confirm success before updating the UI.

**High conflict probability.** Multi-user environments where another user may have modified the same record, inventory systems (quantity could be 0), booking systems (slot could be taken) — the server's response is not a formality, it is the source of truth.

**When the server generates the new state.** If the server assigns an ID, computes a derived field, or runs business logic that changes the shape of the response, the client cannot predict the result. Showing a fake optimistic version creates a jarring replacement effect when the real data arrives.

## Rollback Complexity

Optimistic updates require a rollback path. With TanStack Query's `useMutation`, this means:

1. `onMutate`: snapshot the current cache, apply the optimistic update, return the snapshot as context.
2. `onError`: restore the snapshot from context.
3. `onSettled`: invalidate the query to refetch authoritative data regardless of outcome.

Missing step 3 is a common bug — on success, the optimistic data stays in cache indefinitely without being confirmed by the server.

## The Hybrid Approach

For flows where you want perceived speed but also need server confirmation before the user can proceed further:

- Apply the optimistic update immediately (the item appears in the list).
- Disable follow-on actions (edit, share, delete) until the server confirms.
- On confirmation, enable those actions with the real server ID.

This prevents the double-action race condition while still eliminating the loading state on the primary action.

## Key Rules

- **Never optimistically update destructive actions** (delete, cancel, charge) — the rollback UX is worse than a spinner.
- **Always implement `onError` rollback** when using optimistic updates — skipping it leaves the UI in a permanently inconsistent state.
- **Always call `invalidateQueries` in `onSettled`** — optimistic data is a guess, not a fact; replace it with server truth after the mutation resolves.
- If a form submission creates a resource and the next page needs the server-assigned ID, do not optimistically navigate — wait for the response.
- Optimistic updates and real-time subscriptions interact: if a subscription delivers the same update the optimistic code already applied, de-duplicate by comparing data, not event count.
