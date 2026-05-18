# Principle: Ports and Adapters

## Overview
Ports and Adapters (also called Hexagonal Architecture) solves a specific problem: business logic that's impossible to test because it directly calls SendGrid, Stripe, or the file system. By defining interfaces (ports) that the application core depends on, and having infrastructure provide concrete implementations (adapters), the core becomes independently testable and the infrastructure becomes swappable.

## The Structure

```
                        ┌──────────────────────────┐
  HTTP Request ─────────► Web Adapter               │
  Cron Job ─────────────► Cron Adapter              │
  Queue Message ────────► Queue Adapter  ───────────► Application Core
                        │                            │  (pure domain logic)
  Application Core ────►│ EmailPort (interface)    ◄─┤
                        │   ↑                        │
                        │ SendGridAdapter            │
                        │ MailgunAdapter             │
                        │ MockEmailAdapter (tests)   │
                        └──────────────────────────┘
```

**Ports** are interfaces defined by the application core. The core says "I need something that can send email" without knowing what sends it.

**Adapters** are implementations of those interfaces. Production uses SendGrid. Tests use a mock that records sent emails.

## Code Example

```typescript
// Port: defined in the application core, no external dependencies
interface EmailService {
  send(options: {
    to: string;
    subject: string;
    html: string;
  }): Promise<void>;
}

// Adapter 1: production implementation
class SendGridEmailAdapter implements EmailService {
  async send(options) {
    await sgMail.send({
      to: options.to,
      from: 'noreply@example.com',
      subject: options.subject,
      html: options.html,
    });
  }
}

// Adapter 2: test implementation
class MockEmailAdapter implements EmailService {
  public sent: Array<{ to: string; subject: string }> = [];

  async send(options) {
    this.sent.push({ to: options.to, subject: options.subject });
  }
}

// Application core: depends on the port interface, not any adapter
class OrderService {
  constructor(
    private readonly orders: OrderRepository,
    private readonly email: EmailService,  // port, not SendGrid
  ) {}

  async placeOrder(data: PlaceOrderData): Promise<Order> {
    const order = Order.create(data);
    await this.orders.save(order);
    await this.email.send({
      to: data.customerEmail,
      subject: `Order ${order.id} confirmed`,
      html: renderOrderEmail(order),
    });
    return order;
  }
}
```

## Testing Without Infrastructure

```typescript
test('places order and sends confirmation email', async () => {
  const emailAdapter = new MockEmailAdapter();
  const orderRepo = new InMemoryOrderRepository();
  const service = new OrderService(orderRepo, emailAdapter);

  const order = await service.placeOrder({
    customerId: 'c1',
    customerEmail: 'user@example.com',
    items: [{ productId: 'p1', quantity: 2 }],
  });

  expect(order.status).toBe('confirmed');
  expect(emailAdapter.sent).toHaveLength(1);
  expect(emailAdapter.sent[0].to).toBe('user@example.com');
  // No HTTP calls, no SendGrid API key, no email actually sent
});
```

## Identifying Your Ports

Ports typically correspond to external dependencies:
- **EmailService** — send transactional email
- **StorageService** — upload/download files
- **PaymentService** — charge, refund, create payment intent
- **NotificationService** — send SMS, push notification
- **GeocodingService** — convert address to coordinates
- **Repository** — read/write domain objects (the DB adapter pattern)

## Driving vs Driven Ports

**Driving ports** (inbound): How the outside world triggers the application.
- HTTP adapter calls `OrderService.placeOrder()`
- Cron adapter calls `ReportService.generateMonthly()`

**Driven ports** (outbound): How the application reaches out to infrastructure.
- `OrderService` calls `EmailService.send()`
- `OrderService` calls `OrderRepository.save()`

Both are interfaces. Driving ports are implemented by the application; driven ports are implemented by adapters.

## Key Rules
- The application core defines ports (interfaces); infrastructure provides adapters
- The core never imports infrastructure packages (`@sendgrid/mail`, `aws-sdk`, etc.)
- Every external dependency (email, storage, payment, DB) gets a port
- Production wires real adapters at startup; tests wire mock adapters
- Mocks in tests should implement the port interface, not monkey-patch the real adapter
- Swapping SendGrid for Mailgun means writing a new adapter, not changing any business logic
