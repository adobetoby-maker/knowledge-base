# Skill: typescript-advanced

**Trigger:** TypeScript type system questions — generics, utility types, discriminated unions, conditional types, or improving type safety.
**Returns:** Practical TypeScript patterns for the codebase.

## Discriminated Unions for State Machines

```typescript
// Model all possible states as a union
type AsyncState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error }

// Exhaustive switch narrows correctly
function render(state: AsyncState<Invoice[]>) {
  switch (state.status) {
    case 'idle': return null
    case 'loading': return <Spinner />
    case 'success': return <InvoiceList invoices={state.data} />  // state.data is typed
    case 'error': return <ErrorMessage error={state.error} />
    // TypeScript errors if a case is missing
  }
}
```

Discriminated unions eliminate nullable fields and `if (data && !loading && !error)` chains.

## Branded Types — Prevent ID Mix-ups

```typescript
type UserId = string & { readonly brand: unique symbol }
type InvoiceId = string & { readonly brand: unique symbol }

function createUserId(id: string): UserId { return id as UserId }
function createInvoiceId(id: string): InvoiceId { return id as InvoiceId }

// Now TypeScript prevents passing userId where invoiceId is expected:
function getInvoice(id: InvoiceId) { /* ... */ }

const userId = createUserId('user-123')
getInvoice(userId)  // TypeScript error: UserId is not InvoiceId
```

## Template Literal Types

```typescript
type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH'
type ApiRoute = `/${string}`
type ApiEndpoint = `${HttpMethod} ${ApiRoute}`

const endpoint: ApiEndpoint = 'GET /api/invoices'  // valid
const bad: ApiEndpoint = 'CONNECT /api/invoices'   // TypeScript error
```

## Mapped Types — Transform Object Shapes

```typescript
// Make all properties optional
type Partial<T> = { [K in keyof T]?: T[K] }

// Make all properties required
type Required<T> = { [K in keyof T]-?: T[K] }

// Custom transformation — make all values strings
type Stringify<T> = { [K in keyof T]: string }

// Pick specific keys
type Pick<T, K extends keyof T> = { [P in K]: T[P] }

// Practical: form validation errors
type ValidationErrors<T> = { [K in keyof T]?: string[] }
```

## Conditional Types

```typescript
// Unwrap Promise
type Awaited<T> = T extends Promise<infer U> ? U : T

// Narrow array element type
type ElementType<T extends unknown[]> = T extends (infer E)[] ? E : never

// Remove undefined from union
type NonNullable<T> = T extends null | undefined ? never : T

// Practical: extract route params from URL string
type RouteParams<T extends string> =
  T extends `${string}:${infer Param}/${infer Rest}`
    ? Param | RouteParams<`/${Rest}`>
    : T extends `${string}:${infer Param}`
      ? Param
      : never

// RouteParams<'/blog/:slug/comments/:id'> = 'slug' | 'id'
```

## Utility Types Reference

```typescript
Partial<T>         // All properties optional
Required<T>        // All properties required
Readonly<T>        // All properties readonly
Record<K, V>       // Object with keys K and values V
Pick<T, K>         // Only specified keys
Omit<T, K>         // All keys except specified
Exclude<T, U>      // Union members not in U
Extract<T, U>      // Union members assignable to U
NonNullable<T>     // Remove null and undefined
ReturnType<T>      // Return type of function type
Parameters<T>      // Tuple of function parameter types
Awaited<T>         // Unwrap Promise<T> recursively
```

## Satisfies Operator (TypeScript 4.9+)

```typescript
// Problem: as const loses specific types in objects
const routes = {
  home: '/',
  blog: '/blog',
} as const  // works but can't add methods

// satisfies: validates shape without widening types
const routes = {
  home: '/',
  blog: '/blog',
  getBlogPost: (slug: string) => `/blog/${slug}`,
} satisfies Record<string, string | ((...args: unknown[]) => string)>

routes.home  // typed as '/', not string
```

## Generic Constraints

```typescript
// Constrain to objects with id
function updateById<T extends { id: string }>(items: T[], updated: T): T[] {
  return items.map(item => item.id === updated.id ? updated : item)
}

// Constrain to keyof
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key]
}

// Constrain to async functions
async function retry<T>(
  fn: () => Promise<T>,
  attempts: number
): Promise<T> {
  for (let i = 0; i < attempts; i++) {
    try { return await fn() } catch (e) { if (i === attempts - 1) throw e }
  }
  throw new Error('unreachable')
}
```

## Type Guards

```typescript
// Narrowing with type predicates
function isInvoice(value: unknown): value is Invoice {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    'amount' in value
  )
}

// Assertion function (throws if wrong type)
function assertInvoice(value: unknown): asserts value is Invoice {
  if (!isInvoice(value)) throw new TypeError('Expected Invoice')
}
```
