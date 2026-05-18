# Principle: Database as Source of Truth

## Overview
In any system with multiple components — browser, server, cache, queue, background jobs — only one location can be the authoritative source of truth for a piece of data. The database must be that source. Client-side state is a view of the database, possibly stale and always unverified. Application code computes derived values; the database stores the authoritative ones. When these are out of sync, the database wins. This prevents a class of bugs where two representations diverge and the system makes decisions based on the wrong one.

## Implementation

### Optimistic Updates Must Reconcile
```tsx
// Optimistic update: immediately show success in the UI
// But reconcile with the DB response
function useOptimisticUpdate() {
  const queryClient = useQueryClient();

  const updateUser = useMutation({
    mutationFn: (data: UpdateUserInput) => api.users.update(data),

    onMutate: async (data) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['user', data.id] });

      // Snapshot current state (for rollback)
      const previous = queryClient.getQueryData(['user', data.id]);

      // Optimistically update the UI
      queryClient.setQueryData(['user', data.id], (old: User) => ({
        ...old,
        ...data,
      }));

      return { previous };
    },

    onError: (err, data, context) => {
      // ROLL BACK to DB state on error
      queryClient.setQueryData(['user', data.id], context?.previous);
    },

    onSettled: (data, err, variables) => {
      // ALWAYS refetch from DB after mutation — server response is authoritative
      queryClient.invalidateQueries({ queryKey: ['user', variables.id] });
    },
  });
}
```

### DB Constraints Are the Real Business Rules
Application code can be bypassed (direct SQL, admin tools, bugs, race conditions). Database constraints cannot be:

```sql
-- The DB enforces what no amount of application code can guarantee
CREATE TABLE subscriptions (
  id          UUID PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id),
  plan_id     UUID NOT NULL REFERENCES plans(id),
  status      TEXT NOT NULL DEFAULT 'active',

  -- Business rule: only one active subscription per user
  CONSTRAINT one_active_per_user
    UNIQUE NULLS NOT DISTINCT (user_id, (CASE WHEN status = 'active' THEN TRUE END)),

  -- Business rule: trial must end after it starts
  trial_start TIMESTAMPTZ,
  trial_end   TIMESTAMPTZ,
  CONSTRAINT trial_period_valid CHECK (trial_end IS NULL OR trial_end > trial_start),

  -- Business rule: amount must be positive
  amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0)
);
```

### Never Compute Business-Critical Values Client-Side
```ts
// WRONG: Computing total in the browser
// Client-side totals can be manipulated and should never be trusted
const total = cartItems.reduce((sum, item) => sum + item.price * item.qty, 0);
await api.checkout({ items: cartItems, total }); // DANGEROUS: server trusts client total

// RIGHT: Compute on server, store result in DB
// Server Action:
async function checkout(cartItems: CartItem[]) {
  // Server computes authoritative total from its own product prices
  const products = await db.products.findByIds(cartItems.map(i => i.productId));
  const authorativeTotal = cartItems.reduce((sum, item) => {
    const product = products.find(p => p.id === item.productId);
    return sum + (product?.priceCents ?? 0) * item.qty;
  }, 0);

  const order = await db.orders.create({
    items: cartItems,
    totalCents: authorativeTotal, // from DB, not client
  });

  return order;
}
```

### Cache as a View of DB State
```ts
// Cache stores a snapshot of DB state, not the source of truth
const cache = new Map<string, User>();

async function getUser(id: string): Promise<User> {
  if (cache.has(id)) {
    // Cache hit — return cached view
    return cache.get(id)!;
  }

  // Cache miss — DB is the authority
  const user = await db.users.findById(id);
  if (user) cache.set(id, user);
  return user;
}

// On mutation: invalidate cache, don't just update it
async function updateUser(id: string, data: Partial<User>) {
  const updated = await db.users.update(data, { where: { id } });
  cache.delete(id); // invalidate; next read will fetch fresh from DB
  return updated;
}
```

### Distributed System Conflict Resolution
```ts
// Optimistic locking: DB rejects stale writes
// The DB's version number is the authority on "latest"
async function updateWithOptimisticLock(id: string, data: Partial<Invoice>, version: number) {
  const result = await db.query(`
    UPDATE invoices
    SET data = $1, version = version + 1, updated_at = now()
    WHERE id = $2 AND version = $3
    RETURNING *
  `, [data, id, version]);

  if (result.rows.length === 0) {
    // DB rejected the update — someone else updated first
    throw new ConflictError('Invoice was modified by another user. Please refresh.');
  }

  return result.rows[0];
}
```

## Key Rules
- The database is authoritative — if client state and DB state disagree, the DB is correct.
- Always invalidate cache on write — updating the cache in-place instead of invalidating risks serving the cached (wrong) value if the DB write fails.
- Business-critical calculations (totals, amounts, balances) must be computed server-side using DB-sourced prices — never trust client-provided totals.
- DB constraints (UNIQUE, CHECK, FK, NOT NULL) encode business rules that cannot be bypassed — always add appropriate constraints.
- Optimistic updates in the UI are a UX feature, not a source of truth — they must always be reconciled with the DB response.
- The `updated_at` column should be set by a DB trigger (`DEFAULT now()`) or DB function, not by application code — clocks differ between application servers.
- Race conditions in application code cannot be prevented by application code alone — use DB transactions and constraints.
