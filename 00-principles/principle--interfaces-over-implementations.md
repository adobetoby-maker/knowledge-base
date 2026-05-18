# Principle: Interfaces Over Implementations

## Overview
When a caller depends on a concrete implementation, it inherits all of that implementation's constraints: its third-party SDK, its network calls, its database schema. When a caller depends on an interface (a contract of what behavior is provided), it can work with any implementation of that contract — including a mock in tests, a different provider in a different environment, or a new implementation built in parallel. This is the Dependency Inversion Principle: high-level modules should not depend on low-level modules; both should depend on abstractions.

## The Core Pattern

```typescript
// Interface (the contract)
interface EmailSender {
  send(to: string, subject: string, body: string): Promise<{ messageId: string }>;
}

// Production implementation
class SendGridEmailSender implements EmailSender {
  async send(to, subject, body) {
    const response = await sendgrid.mail.send({ to, subject, html: body });
    return { messageId: response[0].headers['x-message-id'] };
  }
}

// Test implementation — no network calls, deterministic
class MockEmailSender implements EmailSender {
  sent: Array<{ to: string; subject: string; body: string }> = [];
  async send(to, subject, body) {
    this.sent.push({ to, subject, body });
    return { messageId: "mock-id-" + this.sent.length };
  }
}

// Caller depends only on the interface
class UserService {
  constructor(private emailSender: EmailSender) {}
  
  async sendWelcomeEmail(user: User) {
    await this.emailSender.send(user.email, "Welcome!", `Hi ${user.name}`);
  }
}

// Tests
const mock = new MockEmailSender();
const service = new UserService(mock);
await service.sendWelcomeEmail(testUser);
expect(mock.sent[0].to).toBe(testUser.email);

// Production
const service = new UserService(new SendGridEmailSender());
```

## What This Enables

**Mocking in tests without network calls.** Tests run fast, deterministically, without requiring real credentials or hitting rate limits.

**Swapping providers.** Moving from SendGrid to Resend changes one line in the composition root, not every file that sends email.

**Parallel development.** Team A builds the `UserService` while Team B builds the `SendGridEmailSender`. Both work against the interface contract.

**Gradual migration.** A strangler-fig `EmailSender` that calls the old system for existing users and the new system for new users — callers don't know.

## Where to Define Interfaces

Define interfaces in the layer that *uses* them, not the layer that *implements* them. The `UserService` owns the `EmailSender` interface. This keeps the dependency arrow pointing the right direction: the infrastructure layer (`SendGridEmailSender`) depends on the domain/application layer (`EmailSender` interface), not the other way.

```
app/
  services/
    user-service.ts        ← defines EmailSender interface
  email/
    sendgrid-sender.ts     ← imports and implements EmailSender interface
```

## Practical Scope
Not every class needs an interface. Apply when:
- The dependency involves I/O (network, filesystem, clock, random)
- The dependency might be swapped (provider, DB engine)
- The dependency needs to be mocked in tests
- The dependency is in a different bounded context

Don't create interfaces for pure data transformation functions or simple value objects — that's ceremony without benefit.

## Key Rules
- Interfaces live in the module that consumes them (dependency inversion)
- I/O at the boundary means interface at the boundary
- Mock implementations belong in test utilities, not scattered inline in test files
- The interface should describe *what*, not *how* — no implementation details leak into method signatures
- One interface per purpose; don't bundle unrelated methods just because one class implements them (Interface Segregation Principle)
