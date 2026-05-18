# Plugin: ts-pattern (Pattern Matching)

## Overview

Exhaustive pattern matching for TypeScript. ts-pattern makes complex conditional logic readable and type-safe — the compiler enforces that every case is handled. Most valuable for discriminated unions, nested state combinations, and conditional rendering based on multiple fields.

## Installation

```bash
npm install ts-pattern
```

## Basic Pattern Matching

```ts
import { match, P } from 'ts-pattern'

type Status = 'idle' | 'loading' | 'success' | 'error'

// Without ts-pattern — verbose and error-prone
function getMessage(status: Status, errorMsg?: string): string {
  if (status === 'idle') return 'Ready'
  if (status === 'loading') return 'Loading...'
  if (status === 'success') return 'Done!'
  if (status === 'error') return errorMsg ?? 'Failed'
  throw new Error('Unknown status')
}

// With ts-pattern — exhaustive and readable
function getMessage(status: Status, errorMsg?: string): string {
  return match(status)
    .with('idle', () => 'Ready')
    .with('loading', () => 'Loading...')
    .with('success', () => 'Done!')
    .with('error', () => errorMsg ?? 'Failed')
    .exhaustive()  // Compiler error if a case is missing
}
```

## Discriminated Unions

```ts
type Event =
  | { type: 'USER_CREATED'; userId: string; email: string }
  | { type: 'ORDER_PLACED'; orderId: string; amount: number }
  | { type: 'PAYMENT_FAILED'; orderId: string; reason: string }

async function handleEvent(event: Event) {
  return match(event)
    .with({ type: 'USER_CREATED' }, ({ userId, email }) => sendWelcomeEmail(email, userId))
    .with({ type: 'ORDER_PLACED' }, ({ orderId, amount }) => processPayment(orderId, amount))
    .with({ type: 'PAYMENT_FAILED' }, ({ orderId, reason }) => notifyFailure(orderId, reason))
    .exhaustive()
}
```

TypeScript narrows the event type inside each handler — no casting needed.

## Nested Patterns

```ts
type State = {
  status: 'idle' | 'loading' | 'error' | 'success'
  user: { role: 'admin' | 'user' | null }
}

const message = match(state)
  .with({ status: 'loading' }, () => 'Loading...')
  .with({ status: 'error' }, () => 'Failed')
  .with({ status: 'success', user: { role: 'admin' } }, () => 'Welcome, Admin')
  .with({ status: 'success', user: { role: 'user' } }, () => 'Welcome back')
  .with({ status: 'success', user: { role: null } }, () => 'Welcome, guest')
  .with({ status: 'idle' }, () => '')
  .exhaustive()
```

## Pattern Wildcards

```ts
import { P } from 'ts-pattern'

match(value)
  .with(P.string, s => `string: ${s}`)
  .with(P.number, n => `number: ${n}`)
  .with(P.boolean, b => `boolean: ${b}`)
  .with(null, () => 'null')
  .with(P._, () => 'anything else')  // Wildcard
  .exhaustive()

// Guards
.with(P.number.gt(0), n => `positive: ${n}`)
.with(P.string.minLength(1), s => `non-empty: ${s}`)
.with(P.array(P.string), arr => arr.join(', '))
```

## React Component Rendering

```tsx
function RequestStatus({ request }: { request: ApiRequest }) {
  return match(request)
    .with({ status: 'idle' }, () => <IdleState />)
    .with({ status: 'loading' }, () => <Skeleton />)
    .with({ status: 'error' }, ({ error }) => <ErrorState message={error.message} />)
    .with({ status: 'success' }, ({ data }) => <DataView data={data} />)
    .exhaustive()
}
```

## When NOT to Use

- Simple binary conditions: `isPro ? <Pro /> : <Free />` — use ternary
- Single type check: `typeof x === 'string'` — use direct check
- Switch statements on string enums with simple bodies — switch is fine

ts-pattern adds value when you have 3+ branches or multiple discriminant fields combined.

## Key Rules

- `.exhaustive()` is the key feature — always use it on discriminated unions to get compiler enforcement.
- `.otherwise()` is the escape hatch — use sparingly; it removes exhaustiveness.
- `P._` (wildcard) at the end handles remaining cases — equivalent to `default` in switch.
- Pattern matching runs top-to-bottom and short-circuits on first match — order matters for overlapping patterns.
