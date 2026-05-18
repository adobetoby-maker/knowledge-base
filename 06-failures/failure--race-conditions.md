# Failure: Race Conditions

## What Race Conditions Look Like

Race conditions produce intermittent, hard-to-reproduce bugs where the outcome depends on timing: two operations executing "at the same time" interfere with each other. In web apps, they appear as:
- Double charges from double-click
- Duplicate database rows from concurrent inserts
- Inventory overselling
- Stale data overwrites (lost update)
- Auth bypass from TOCTOU (time-of-check to time-of-use)

## Pattern 1: Double Submit

```tsx
// WRONG — no protection against double submit
function CheckoutButton() {
  async function handleClick() {
    await createOrder()
  }
  return <button onClick={handleClick}>Place Order</button>
}

// CORRECT — disable during processing
function CheckoutButton() {
  const [submitting, setSubmitting] = useState(false)

  async function handleClick() {
    if (submitting) return
    setSubmitting(true)
    try {
      await createOrder()
    } finally {
      setSubmitting(false)
    }
  }

  return <button onClick={handleClick} disabled={submitting}>Place Order</button>
}
```

## Pattern 2: TOCTOU — Check Then Act

```ts
// WRONG — race between the read and the write
async function decrementInventory(productId: string, quantity: number) {
  const { data: product } = await supabase
    .from('products')
    .select('stock')
    .eq('id', productId)
    .single()

  if (product.stock < quantity) throw new Error('Out of stock')

  // Another request could read the same stock level here
  await supabase
    .from('products')
    .update({ stock: product.stock - quantity })
    .eq('id', productId)
}

// CORRECT — atomic conditional update
async function decrementInventory(productId: string, quantity: number) {
  const { data, error } = await supabase
    .from('products')
    .update({ stock: supabase.rpc('decrement', { amount: quantity }) })
    .eq('id', productId)
    .gt('stock', quantity - 1)  // Condition in the UPDATE
    .select('stock')
    .single()

  if (!data) throw new Error('Out of stock or concurrent purchase')
}
```

Better — use a database function:

```sql
CREATE OR REPLACE FUNCTION purchase_inventory(p_product_id UUID, p_quantity INT)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
  remaining INTEGER;
BEGIN
  UPDATE products
  SET stock = stock - p_quantity
  WHERE id = p_product_id AND stock >= p_quantity
  RETURNING stock INTO remaining;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient stock';
  END IF;

  RETURN remaining;
END;
$$;
```

## Pattern 3: Concurrent Inserts

```ts
// WRONG — two requests create duplicate records
async function createProfile(userId: string, data: ProfileData) {
  const { data: existing } = await supabase.from('profiles').select('id').eq('user_id', userId).single()
  if (existing) return existing

  const { data: created } = await supabase.from('profiles').insert({ user_id: userId, ...data }).single()
  return created
}

// CORRECT — use upsert with unique constraint
async function createProfile(userId: string, data: ProfileData) {
  const { data } = await supabase
    .from('profiles')
    .upsert({ user_id: userId, ...data }, { onConflict: 'user_id' })
    .select()
    .single()
  return data
}
```

The unique constraint on `user_id` plus `upsert` makes the operation atomic. The database guarantees exactly one row.

## Pattern 4: React State Race

```tsx
// WRONG — stale closure captures old state value
function Counter() {
  const [count, setCount] = useState(0)

  async function handleIncrement() {
    await someAsyncOperation()
    setCount(count + 1)  // count may be stale if component re-rendered during async
  }
}

// CORRECT — functional update reads current state
function Counter() {
  const [count, setCount] = useState(0)

  async function handleIncrement() {
    await someAsyncOperation()
    setCount((prev) => prev + 1)  // prev is always current
  }
}
```

## Pattern 5: Concurrent Server Action Calls

```ts
// WRONG — multiple rapid calls create multiple records
async function saveUserPreference(key: string, value: string) {
  await supabase.from('preferences').insert({ user_id: userId, key, value })
}

// CORRECT — upsert on composite unique key
async function saveUserPreference(key: string, value: string) {
  await supabase
    .from('preferences')
    .upsert({ user_id: userId, key, value }, { onConflict: 'user_id,key' })
}
```

## Pattern 6: Optimistic UI Without Rollback

```tsx
// WRONG — optimistic update never rolled back on error
async function likePost(postId: string) {
  setLikeCount(prev => prev + 1)  // Optimistic
  await supabase.from('likes').insert({ post_id: postId, user_id })
  // If insert fails, count is wrong forever
}

// CORRECT — rollback on failure
async function likePost(postId: string) {
  const prev = likeCount
  setLikeCount(prev + 1)  // Optimistic

  const { error } = await supabase.from('likes').insert({ post_id: postId, user_id })
  if (error) {
    setLikeCount(prev)  // Rollback
    toast.error('Failed to like post')
  }
}
```

## Detection Strategy

Race conditions rarely appear in unit tests — they require concurrent load. Detection strategies:
1. **Load testing**: Send 10 concurrent identical requests, check for duplicates
2. **Database constraints**: Unique constraints catch duplicate inserts in production
3. **Audit logs**: Log every write with a request ID — duplicates become visible
4. **Alerting**: Alert when a unique constraint violation occurs in production — it reveals a race in the application layer
