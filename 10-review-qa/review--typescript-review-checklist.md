# TypeScript Review Checklist

## Type Safety

- [ ] No `any` types (if unavoidable, use `unknown` with runtime checks instead)
- [ ] No unchecked type casts (`as SomeType`) without validation
- [ ] External data validated with Zod before TypeScript types are applied
- [ ] No `!` non-null assertions on values that could genuinely be null
- [ ] Union types used for values with multiple valid shapes
- [ ] Discriminated unions used for state machines and error/success patterns

## Common Type Mistakes

```typescript
// WRONG — as cast without validation:
const invoice = data as Invoice

// CORRECT — validate then type:
const result = InvoiceSchema.safeParse(data)
if (result.success) {
  const invoice: Invoice = result.data
}

// WRONG — optional chaining hiding a real error:
const name = user?.profile?.name  // masks that user or profile might be wrong

// CORRECT — validate upstream that user and profile exist
// Then access directly: user.profile.name
```

## Money Types

- [ ] Money values stored as integers (cents), never floats
- [ ] Money variable names include `_cents` suffix
- [ ] Display formatting uses `(cents / 100).toFixed(2)`, not `cents / 100` directly

## Status/Enum Fields

- [ ] Status fields are typed as string literal unions, not plain `string`
- [ ] Switch statements on union types have exhaustive handling
- [ ] New status values update both the union type AND the runtime validation

```typescript
// CORRECT:
type InvoiceStatus = 'draft' | 'pending' | 'paid' | 'overdue' | 'cancelled'

// Exhaustive switch:
function getStatusLabel(status: InvoiceStatus): string {
  switch (status) {
    case 'draft': return 'Draft'
    case 'pending': return 'Pending'
    case 'paid': return 'Paid'
    case 'overdue': return 'Overdue'
    case 'cancelled': return 'Cancelled'
    default: {
      const _check: never = status
      return 'Unknown'
    }
  }
}
```

## React Props

- [ ] Props typed with `interface` (not inline type literal)
- [ ] Optional props use `?:` not `| undefined` (they're equivalent but `?:` is cleaner)
- [ ] Event handler props named `on[Action]` and typed as `() => void` or `(value: T) => void`
- [ ] No `any` in component props

## Supabase Types

- [ ] Generated types from `lib/database.types.ts` used (not manually written)
- [ ] Type aliases in `lib/types.ts` for clean usage: `type Invoice = Database['public']['Tables']['invoices']['Row']`
- [ ] `Insert` and `Update` types used for mutations (not the `Row` type)

## Async/Await

- [ ] All async functions have `await` or explicit `void` return
- [ ] Promise.all used for parallel operations, not sequential awaits
- [ ] Error handling: either try/catch or `.catch()`, not unhandled promises

## Server vs Client Types

- [ ] Types shared between server and client are in `lib/types.ts` (no 'use client' code)
- [ ] Types that include server-only fields (service role keys, admin-only data) not exposed to client
- [ ] `Partial<>` not used where all fields are actually required

## File Organization

- [ ] Component props interfaces defined at the top of the file
- [ ] Shared types in `lib/types.ts`, not scattered across component files
- [ ] Database types imported from generated file, not rewritten
