# Plugin: neverthrow

## Overview

neverthrow brings Rust-style `Result<T, E>` types to TypeScript. Instead of throwing exceptions, functions return `Ok(value)` or `Err(error)` — forcing callers to handle both outcomes at the type level. Best for domain logic, API calls, and validation where error types matter and you want to avoid uncaught exceptions.

## Installation

```bash
npm install neverthrow
```

## Core Types

```ts
import { ok, err, Result, ResultAsync } from 'neverthrow'

// Synchronous
function divide(a: number, b: number): Result<number, string> {
  if (b === 0) return err('Division by zero')
  return ok(a / b)
}

// Async
async function fetchUser(id: string): Promise<Result<User, ApiError>> {
  try {
    const user = await db.query.users.findFirst({ where: eq(users.id, id) })
    if (!user) return err({ code: 'NOT_FOUND', message: 'User not found' })
    return ok(user)
  } catch (e) {
    return err({ code: 'DB_ERROR', message: String(e) })
  }
}
```

## Consuming Results

```ts
const result = divide(10, 2)

// Pattern match
if (result.isOk()) {
  console.log(result.value)  // TypeScript knows type is number
} else {
  console.error(result.error)  // TypeScript knows type is string
}

// .match() — like Rust's match
const display = result.match(
  value => `Result: ${value}`,
  error => `Error: ${error}`
)

// .unwrapOr() — provide a default on error
const value = result.unwrapOr(0)
```

## Chaining with .andThen()

```ts
function validateEmail(email: string): Result<string, string> {
  if (!email.includes('@')) return err('Invalid email format')
  return ok(email.toLowerCase())
}

function validateAge(age: number): Result<number, string> {
  if (age < 18) return err('Must be 18 or older')
  return ok(age)
}

function validateSignup(input: { email: string; age: number }): Result<SignupData, string> {
  return validateEmail(input.email)
    .andThen(email =>
      validateAge(input.age).map(age => ({ email, age }))
    )
}
```

## ResultAsync for Async Chains

```ts
import { ResultAsync, fromPromise } from 'neverthrow'

function fetchUser(id: string): ResultAsync<User, ApiError> {
  return fromPromise(
    db.query.users.findFirst({ where: eq(users.id, id) }),
    (e) => ({ code: 'DB_ERROR' as const, message: String(e) })
  ).andThen(user => {
    if (!user) return err({ code: 'NOT_FOUND' as const, message: 'Not found' })
    return ok(user)
  })
}

// Chaining async results
const result = await fetchUser(id)
  .andThen(user => fetchOrders(user.id))
  .map(orders => orders.filter(o => o.status === 'pending'))

if (result.isErr()) {
  // Handle typed error
}
```

## In Route Handlers

```ts
export async function POST(req: Request) {
  const body = await req.json()

  const result = await createOrder(body)

  return result.match(
    order => Response.json(order, { status: 201 }),
    error => {
      switch (error.code) {
        case 'VALIDATION_ERROR':
          return Response.json({ error: error.message }, { status: 400 })
        case 'OUT_OF_STOCK':
          return Response.json({ error: 'Product unavailable' }, { status: 409 })
        default:
          return Response.json({ error: 'Internal error' }, { status: 500 })
      }
    }
  )
}
```

## combineResultList — Aggregate Multiple Results

```ts
import { Result } from 'neverthrow'

// All must succeed — returns first error if any fail
const results = Result.combine([
  validateName(name),
  validateEmail(email),
  validateAge(age),
])

if (results.isErr()) {
  return err(results.error)  // First validation failure
}

const [validName, validEmail, validAge] = results.value
```

## neverthrow vs try/catch

| Concern | try/catch | neverthrow |
|---|---|---|
| Error type safety | None | Full TypeScript types |
| Forced error handling | No (silent failures) | Yes (compiler enforces) |
| Composability | Low | High (.andThen chains) |
| Learning curve | None | Moderate |
| Async support | async/await | ResultAsync |

## Key Rules

- Use neverthrow for domain logic that has meaningful error variants — not for unexpected runtime errors (let those throw).
- `fromPromise(promise, mapErr)` wraps existing promises — the second argument maps the caught exception to your error type.
- `Result.combine` short-circuits on first failure — use `Result.combineWithAllErrors` to collect all failures.
- Don't use neverthrow at every layer — use it at domain/service boundaries, not utility functions.
- Discriminated union error types (`{ code: 'NOT_FOUND' | 'DB_ERROR', message: string }`) enable exhaustive switch matching.
