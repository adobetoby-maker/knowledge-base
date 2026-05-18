# Supabase Query Patterns

## Basic CRUD

```typescript
// SELECT
const { data, error } = await supabase
  .from('invoices')
  .select('id, amount, status, created_at')
  .eq('user_id', userId)
  .order('created_at', { ascending: false })
  .limit(10)

// INSERT
const { data, error } = await supabase
  .from('invoices')
  .insert({ user_id: userId, amount: 150.00, status: 'pending' })
  .select()
  .single()

// UPDATE
const { data, error } = await supabase
  .from('invoices')
  .update({ status: 'paid', paid_at: new Date().toISOString() })
  .eq('id', invoiceId)
  .eq('user_id', userId)  // always scope to current user
  .select()
  .single()

// DELETE
const { error } = await supabase
  .from('invoices')
  .delete()
  .eq('id', invoiceId)
  .eq('user_id', userId)
```

Always scope mutations to the current user even when RLS should handle it — defense in depth.

## Select with Joins

```typescript
// One-to-many: invoice with its line items
const { data, error } = await supabase
  .from('invoices')
  .select(`
    id,
    amount,
    status,
    customer:customers(id, name, email),
    line_items(id, description, quantity, unit_price)
  `)
  .eq('id', invoiceId)
  .single()

// data.customer is a single object
// data.line_items is an array
```

The nested select syntax uses the foreign key relationship name. Check Supabase Studio to verify relationship names if queries fail.

## Filtering Patterns

```typescript
// Multiple conditions (AND)
.eq('status', 'active').eq('role', 'admin')

// OR condition
.or('status.eq.active,status.eq.pending')

// IN list
.in('status', ['active', 'pending', 'processing'])

// Date range
.gte('created_at', startDate).lte('created_at', endDate)

// Text search (case-insensitive contains)
.ilike('name', `%${searchTerm}%`)

// Full text search (requires text search column/index)
.textSearch('content', searchTerm)

// Null check
.is('deleted_at', null)
.not('deleted_at', 'is', null)
```

## Pagination

```typescript
const PAGE_SIZE = 20

const { data, count, error } = await supabase
  .from('invoices')
  .select('*', { count: 'exact' })
  .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)

// count is total records matching (before range)
// data is the current page
const totalPages = Math.ceil((count ?? 0) / PAGE_SIZE)
```

Use `.range()` not `.limit()` + `.offset()` when you need cursor-based or range-based pagination.

## Upsert

```typescript
const { data, error } = await supabase
  .from('profiles')
  .upsert({
    user_id: userId,
    xp: newXp,
    updated_at: new Date().toISOString()
  }, {
    onConflict: 'user_id'  // the unique constraint column
  })
  .select()
  .single()
```

## RPC (Stored Procedures)

```typescript
const { data, error } = await supabase
  .rpc('calculate_invoice_total', {
    invoice_id: invoiceId
  })
```

Use RPC for: complex multi-table operations that need atomicity, performance-critical queries with complex joins, operations that need to bypass RLS temporarily (security-definer functions).

## Error Codes to Handle

```typescript
if (error) {
  switch (error.code) {
    case 'PGRST116':
      // No rows returned by .single() query
      return null
    case '23505':
      // Unique constraint violation
      return { error: 'Already exists' }
    case '23503':
      // Foreign key violation
      return { error: 'Referenced record not found' }
    case 'PGRST301':
      // JWT expired
      // Redirect to login
    default:
      throw new Error(error.message)
  }
}
```

## Service Role vs Anon Key Queries

The service role client bypasses ALL RLS. Use it only for:
- Admin operations (seeding, migrations, reports across all users)
- Background jobs that legitimately need cross-user access
- Operations that happen before auth is established (webhook handlers)

Never use service role for user-initiated operations. If the user can trigger it, use the user's JWT-authenticated client so RLS applies.

## N+1 Query Prevention

Wrong:
```typescript
const invoices = await getInvoices()
// Then for each invoice:
for (const invoice of invoices) {
  invoice.customer = await getCustomer(invoice.customer_id)  // N queries
}
```

Right:
```typescript
// One query with join
const { data } = await supabase
  .from('invoices')
  .select('*, customer:customers(id, name, email)')
```

Supabase joins happen in one round-trip. Always prefer joined selects over sequential queries.
