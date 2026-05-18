# TypeScript Common Errors — Diagnosis and Fix

## "Property X does not exist on type Y"

**Cause 1:** Accessing a property that may not exist (optional):
```typescript
const name = user?.profile?.name  // Use optional chaining
```

**Cause 2:** The type is wrong for the actual runtime value:
```typescript
// Type says string, value is object — review source of data
const data = await fetchInvoice()
// Check what fetchInvoice actually returns vs what TypeScript thinks it returns
```

**Cause 3:** Type narrowing needed:
```typescript
if ('message' in error) {
  console.log(error.message)  // now narrowed to type with 'message'
}
```

## "Type X is not assignable to type Y"

**Cause 1:** String not matching enum:
```typescript
type Status = 'active' | 'inactive'
const status: Status = 'pending'  // Error: 'pending' not in union

// Fix: add 'pending' to the union, or cast if you know it's valid
const status = 'pending' as Status  // only if you're certain
```

**Cause 2:** Missing required property:
```typescript
interface Invoice { id: string; amount: number; status: string }
const inv: Invoice = { id: '1', amount: 100 }  // Error: missing status
// Fix: either add status, or make it optional in the interface
```

**Cause 3:** Null/undefined not handled:
```typescript
// Error: Type 'string | null' is not assignable to type 'string'
const name: string = user.name  // user.name might be null

// Fix options:
const name = user.name ?? 'Unknown'  // provide default
if (user.name) { const name = user.name }  // type guard
```

## params Type Error (Next.js 15+)

```
Type error: Type 'Promise<{ slug: string }>' is not assignable to type '{ slug: string }'
```

```typescript
// Wrong (Next.js 14 and earlier):
export default function Page({ params }: { params: { slug: string } }) {
  const { slug } = params

// Correct (Next.js 15+):
export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
```

## "Cannot find module" (Path Alias)

```
Cannot find module '@/components/Button' or its corresponding type declarations
```

Check `tsconfig.json`:
```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"]
    }
  }
}
```

If paths are configured but still failing: check the actual file path and casing (Linux is case-sensitive).

## "useX is not defined" in Server Component

React hooks (useState, useEffect, useContext) cannot be used in Server Components:

```
Error: useState is only available in Client Components. Add the "use client" directive at the top.
```

**Fix:** Add `'use client'` at the top of the file, or move the hook usage to a separate Client Component.

## Generic Type Inference Failure

```typescript
// TypeScript can't infer T
function getItem<T>(items: T[], id: string): T | undefined {
  return items.find(item => item.id === id)  // Error: 'id' not in T
}

// Fix: constrain T to have an id
function getItem<T extends { id: string }>(items: T[], id: string): T | undefined {
  return items.find(item => item.id === id)
}
```

## Exhaustive Switch Type Error

When adding a new union member:
```typescript
type Status = 'pending' | 'paid' | 'cancelled' | 'refunded'  // added 'refunded'

function getLabel(status: Status): string {
  switch (status) {
    case 'pending': return 'Pending'
    case 'paid': return 'Paid'
    case 'cancelled': return 'Cancelled'
    // Error: Function lacks ending return statement — 'refunded' not handled
  }
}

// Fix: add the new case + use never for exhaustiveness
default: {
  const _exhaustive: never = status  // TypeScript error if any case is unhandled
  return _exhaustive
}
```

## Object is Possibly Undefined After Array Access

```typescript
const items = ['a', 'b', 'c']
const first = items[0]  // TypeScript: string | undefined (noUncheckedIndexedAccess)

// Fix:
if (first !== undefined) { /* use first */ }
const first = items[0] ?? 'default'
```

Enable `noUncheckedIndexedAccess` in tsconfig to catch these at compile time.
