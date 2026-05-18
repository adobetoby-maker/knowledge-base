# Which Supabase Operation to Use

## CRUD Quick Reference

| Operation | Method | Example |
|-----------|--------|---------|
| Fetch all rows | `.select('*')` | `supabase.from('invoices').select('*')` |
| Fetch with filter | `.select().eq('col', val)` | `.eq('user_id', user.id)` |
| Fetch one row | `.select().single()` | Returns error if 0 or 2+ rows |
| Fetch first match | `.select().maybeSingle()` | Returns null if not found (no error) |
| Insert row | `.insert(data)` | `.insert({ user_id, amount })` |
| Insert and return | `.insert(data).select().single()` | Returns the inserted row |
| Update | `.update(data).eq('id', id)` | Requires a filter — always use `.eq()` |
| Upsert | `.upsert(data, { onConflict: 'id' })` | Insert or update on conflict |
| Delete | `.delete().eq('id', id)` | Requires a filter — always use `.eq()` |
| Soft delete | `.update({ deleted_at: new Date() }).eq('id', id)` | Keep data, mark deleted |

## Common Mistakes

### Update Without Filter

```typescript
// DANGER — updates ALL rows in the table
await supabase.from('invoices').update({ status: 'paid' })

// CORRECT — always filter
await supabase.from('invoices').update({ status: 'paid' }).eq('id', invoiceId)
```

Supabase requires a `.eq()` or similar filter for updates and deletes. Without one, it tries to update every row. The JS client will error on this (as a safety mechanism), but always verify.

### single() vs maybeSingle()

```typescript
// single() — throws PGRST116 if no rows found
const { data, error } = await supabase
  .from('invoices')
  .select('*')
  .eq('id', id)
  .single()
// error.code === 'PGRST116' means "not found"

// maybeSingle() — returns null data (no error) if not found
const { data, error } = await supabase
  .from('invoices')
  .select('*')
  .eq('id', id)
  .maybeSingle()
// data === null means not found, no error
```

Use `single()` when the row MUST exist (logged-in user's profile). Use `maybeSingle()` when absence is expected (lookup by slug, optional join).

## Joins

```typescript
// Inner join via foreign key
const { data } = await supabase
  .from('invoices')
  .select('*, customers(name, email)')  // customers is the FK table

// Left join (includes rows where FK is null)
const { data } = await supabase
  .from('invoices')
  .select('*, customers(name)')
  .order('created_at', { ascending: false })

// Nested select — only get specific customer fields
const { data } = await supabase
  .from('line_items')
  .select('*, invoices!inner(number, status)')
  .eq('invoices.status', 'pending')
```

## Aggregates

```typescript
// Count total rows
const { count } = await supabase
  .from('invoices')
  .select('*', { count: 'exact', head: true })  // head: true = no rows, just count
  .eq('user_id', userId)

// Count with data
const { data, count } = await supabase
  .from('invoices')
  .select('*', { count: 'exact' })
  .range(0, 19)
```

## Search/Filter Patterns

```typescript
// ILIKE — case-insensitive contains
.ilike('customer_name', `%${query}%`)

// Multiple values (IN)
.in('status', ['pending', 'overdue'])

// Range
.gte('amount', 100).lte('amount', 1000)

// Not null
.not('paid_at', 'is', null)

// Is null
.is('deleted_at', null)

// OR condition
.or('status.eq.pending,status.eq.overdue')

// Full text search (requires tsvector column)
.textSearch('search_vector', query, { type: 'websearch' })
```

## RPC (Stored Procedures)

```typescript
// Call a Postgres function
const { data } = await supabase.rpc('get_invoice_stats', {
  p_user_id: userId,
  p_year: 2026,
})
```

Use RPC for complex queries that would be clunky with the JS client: aggregations, multi-step logic, transactions.
