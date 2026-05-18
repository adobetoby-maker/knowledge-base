# Principle: Dependency Injection

## Overview

Dependency injection (DI) means passing dependencies in rather than importing them directly. Functions receive their dependencies as arguments or constructor parameters rather than creating them internally. This makes code testable (swap real for mock), configurable (different DB in test vs prod), and decoupled (change the implementation without touching callers).

## The Problem with Hardcoded Dependencies

```ts
// BAD — hardcoded import, impossible to test without real Resend API
import { Resend } from 'resend'

const resend = new Resend(process.env.RESEND_API_KEY)

export async function sendWelcomeEmail(userId: string) {
  const user = await db.query.users.findFirst({ where: eq(users.id, userId) })
  await resend.emails.send({ to: user!.email, subject: 'Welcome!' })
}

// Test requires real Resend API or Jest module mock hackery
```

## Constructor Injection (Classes)

```ts
// GOOD — dependency is injected
interface EmailClient {
  send(options: { to: string; subject: string; html: string }): Promise<void>
}

class UserNotificationService {
  constructor(
    private readonly emailClient: EmailClient,
    private readonly db: Database
  ) {}

  async sendWelcomeEmail(userId: string): Promise<void> {
    const user = await this.db.query.users.findFirst({ where: eq(users.id, userId) })
    if (!user) throw new Error('User not found')
    await this.emailClient.send({
      to: user.email,
      subject: 'Welcome!',
      html: '<p>Thanks for signing up.</p>',
    })
  }
}

// Production
const service = new UserNotificationService(resend, db)

// Test — inject a mock
const mockEmailClient: EmailClient = {
  send: vi.fn().mockResolvedValue(undefined),
}
const service = new UserNotificationService(mockEmailClient, testDb)
await service.sendWelcomeEmail(userId)
expect(mockEmailClient.send).toHaveBeenCalledWith({ to: 'test@example.com', subject: 'Welcome!' })
```

## Function-Style DI

For functional codebases, pass dependencies as function arguments:

```ts
// GOOD — dependencies as parameters
async function sendWelcomeEmail(
  userId: string,
  deps: {
    emailClient: EmailClient
    getUserById: (id: string) => Promise<User | null>
  }
): Promise<void> {
  const user = await deps.getUserById(userId)
  if (!user) throw new Error('User not found')
  await deps.emailClient.send({ to: user.email, subject: 'Welcome!', html: '<p>Welcome!</p>' })
}

// Production
await sendWelcomeEmail(userId, {
  emailClient: resend,
  getUserById: (id) => db.query.users.findFirst({ where: eq(users.id, id) }),
})

// Test
await sendWelcomeEmail(userId, {
  emailClient: { send: vi.fn() },
  getUserById: async () => ({ id: userId, email: 'test@example.com', name: 'Test' }),
})
```

## Factory Functions

Partially applied dependencies via closures:

```ts
function createEmailService(emailClient: EmailClient) {
  return {
    async sendWelcomeEmail(userId: string) {
      // emailClient is in closure
    },
    async sendPasswordReset(userId: string) {
      // emailClient is in closure
    },
  }
}

// Create once at app startup
const emailService = createEmailService(resend)

// Test
const testEmailService = createEmailService({ send: vi.fn() })
```

## Context/Provider Pattern (React)

DI in React via Context — swap implementations at the tree level:

```tsx
const ApiContext = createContext<ApiClient | null>(null)

export function useApi(): ApiClient {
  const api = useContext(ApiContext)
  if (!api) throw new Error('useApi must be inside ApiProvider')
  return api
}

// Production
<ApiContext.Provider value={realApiClient}>
  <App />
</ApiContext.Provider>

// Tests
<ApiContext.Provider value={mockApiClient}>
  <ComponentUnderTest />
</ApiContext.Provider>
```

## When Not to Use DI

DI adds indirection — don't apply it uniformly:

```ts
// Overkill for a stable utility with no I/O
function formatDate(date: Date): string {  // No DI needed
  return format(date, 'yyyy-MM-dd')
}

// Reasonable — crypto can be mocked for deterministic test
async function generateToken(crypto: CryptoService): Promise<string> {
  return crypto.randomBytes(32).toString('hex')
}
```

Use DI when:
- The dependency does I/O (network, disk, DB)
- The dependency is expensive to create
- You need different behavior in test vs production
- Multiple implementations might exist

Skip DI when:
- Pure functions with no side effects
- Stable utilities that don't need swapping
- The overhead of abstraction exceeds the benefit

## Key Rules

- Inject interfaces, not concrete types — callers are decoupled from the specific implementation.
- Create dependencies once at the application boundary (startup), not inside every function.
- DI doesn't require a DI framework — function parameters and closures are sufficient for most TypeScript apps.
- Repository pattern (`getUserById` function) injected as a dependency is more testable than injecting the entire ORM.
