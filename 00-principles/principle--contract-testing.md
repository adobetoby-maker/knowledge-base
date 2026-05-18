# Principle: Contract Testing

## Overview

Contract testing verifies that a service provider and its consumer agree on the API contract — request shape, response shape, error codes. Unlike integration tests (which require a live service), contract tests run against a mock that captures the agreement. Pact is the standard framework; for simpler cases, snapshot-based testing or Zod schema validation serves the same purpose.

## The Problem

```
Service A (consumer) → calls → Service B (provider)
Service B team changes the /users/:id response shape
Service A breaks in production — no test caught it
```

Unit tests of A don't call B. Integration tests of A require a live B. Contract tests fill the gap: they verify A and B agree on the API shape without a live connection.

## Approach 1: Zod Schema at Boundaries (Lightweight)

For internal services where you control both sides, parse API responses with Zod. The schema IS the contract.

```ts
// shared/contracts/user.ts
import { z } from 'zod'

export const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string(),
  role: z.enum(['user', 'admin']),
  createdAt: z.string().datetime(),
})

export type User = z.infer<typeof UserSchema>
```

```ts
// Consumer (Service A) — parse and validate response
async function getUser(id: string): Promise<User> {
  const res = await fetch(`${USER_SERVICE_URL}/users/${id}`)
  const data = await res.json()
  return UserSchema.parse(data)  // Throws if contract is violated
}
```

```ts
// Provider (Service B) — validate output before sending
app.get('/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id)
  const validated = UserSchema.parse(user)  // Validates own output matches contract
  res.json(validated)
})
```

When Service B changes the response shape, `UserSchema.parse` fails immediately in Service A's tests or runtime, making the contract break visible.

## Approach 2: API Response Snapshots

```ts
// __tests__/contracts/user-api.test.ts
test('GET /users/:id contract', async () => {
  const res = await request(app).get('/users/user-123')
  expect(res.status).toBe(200)
  // Snapshot captures exact shape — changes require explicit approval
  expect(res.body).toMatchSnapshot()
})
```

Snapshot tests fail when the response shape changes. The developer must explicitly update the snapshot and review the diff. Useful for catching unintentional changes.

## Approach 3: Pact (Full Consumer-Driven Contract Testing)

```ts
// Consumer side: define expected interaction
import { PactV3, MatchersV3 } from '@pact-foundation/pact'

const { string, uuid, datetime } = MatchersV3

const provider = new PactV3({ consumer: 'ServiceA', provider: 'ServiceB' })

describe('User service contract', () => {
  test('returns user by ID', async () => {
    await provider
      .given('user with id user-123 exists')
      .uponReceiving('a request for user user-123')
      .withRequest({ method: 'GET', path: '/users/user-123' })
      .willRespondWith({
        status: 200,
        body: {
          id: uuid(),
          email: string('user@example.com'),
          name: string('Test User'),
        },
      })
      .executeTest(async (mockProvider) => {
        const user = await getUser('user-123', mockProvider.url)
        expect(user.email).toMatch(/@/)
      })
  })
})
```

Pact generates a "pact file" (JSON contract). The provider runs `pact:verify` against this file to confirm it meets all consumer expectations.

## Versioning the Contract

```ts
// shared/contracts/user.ts
export const UserSchemaV2 = UserSchema.extend({
  avatarUrl: z.string().url().nullable(),  // New field — optional for backward compat
})

// Provider supports both: check which version the consumer requested
// Or: always return V2, V1 consumers use .pick() to ignore unknown fields
```

Zod's `.passthrough()` vs `.strict()` controls unknown field handling:
- `.passthrough()` (default): extra fields in response are ignored — backward compatible
- `.strict()`: extra fields throw — strict contract

## Key Rules

- The shared Zod schema is the most pragmatic contract for monorepos and internal APIs — no separate tool needed.
- Parse responses at the system boundary (when data enters your service), not deep in business logic.
- Provider must validate its own output against the contract schema — not just the consumer. Both sides own the contract.
- When changing an API, add fields as optional first (expand), migrate consumers, then make them required (contract). Never remove or rename fields in a single step.
- Pact is worth the overhead for cross-team or cross-organization APIs where you can't coordinate deployments.
