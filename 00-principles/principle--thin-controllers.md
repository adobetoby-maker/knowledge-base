# Principle: Thin Controllers / Route Handlers

## Overview
A route handler's job is to translate HTTP into business logic, not to contain it. When business logic lives in route handlers, it becomes impossible to test without spinning up an HTTP server, impossible to reuse across multiple endpoints, and impossible to read without understanding HTTP at the same time as the domain. The fix is a service layer that contains logic and can be called from any context — route handlers, background jobs, CLI scripts, tests.

## Implementation

### Fat Controller (Anti-Pattern)
```ts
// POST /api/invoices — DO NOT DO THIS
export async function POST(req: Request) {
  const session = await getSession(req);
  if (!session) return Response.json({ error: 'Unauthorized' }, { status: 401 });

  const body = await req.json();
  if (!body.customerId) return Response.json({ error: 'customerId required' }, { status: 400 });
  if (!body.lineItems?.length) return Response.json({ error: 'lineItems required' }, { status: 400 });

  const customer = await db.customers.findById(body.customerId);
  if (!customer) return Response.json({ error: 'Customer not found' }, { status: 404 });
  if (customer.userId !== session.userId) return Response.json({ error: 'Forbidden' }, { status: 403 });

  // Business logic mixed with HTTP handling
  const subtotal = body.lineItems.reduce((s: number, item: any) => s + item.qty * item.price, 0);
  const tax = subtotal * 0.085;
  const total = subtotal + tax;

  const invoice = await db.invoices.create({
    customerId: body.customerId,
    userId: session.userId,
    lineItems: body.lineItems,
    subtotalCents: Math.round(subtotal * 100),
    taxCents: Math.round(tax * 100),
    totalCents: Math.round(total * 100),
    status: 'draft',
    dueAt: new Date(Date.now() + 30 * 86400_000),
  });

  await sendEmail(customer.email, 'invoice-created', { invoice });

  return Response.json({ invoice }, { status: 201 });
}
```

### Thin Controller + Service Layer (Correct)
```ts
// lib/services/invoiceService.ts
export class InvoiceService {
  async create(input: CreateInvoiceInput, userId: string): Promise<Invoice> {
    const customer = await db.customers.findById(input.customerId);
    if (!customer) throw new NotFoundError('Customer not found');
    if (customer.userId !== userId) throw new ForbiddenError('Customer access denied');

    const subtotal = input.lineItems.reduce((s, item) => s + item.qty * item.price, 0);
    const tax = subtotal * 0.085;
    const total = subtotal + tax;

    const invoice = await db.invoices.create({
      customerId: input.customerId,
      userId,
      lineItems: input.lineItems,
      subtotalCents: Math.round(subtotal * 100),
      taxCents: Math.round(tax * 100),
      totalCents: Math.round(total * 100),
      status: 'draft',
      dueAt: new Date(Date.now() + 30 * 86400_000),
    });

    await sendEmail(customer.email, 'invoice-created', { invoice });
    return invoice;
  }
}

// app/api/invoices/route.ts — THIN CONTROLLER
const invoiceService = new InvoiceService();

export async function POST(req: Request) {
  const session = await requireSession(req);           // throws on failure
  const body = await parseBody(req, createInvoiceSchema); // throws on validation failure

  const invoice = await invoiceService.create(body, session.userId);
  return Response.json({ invoice }, { status: 201 });
}
```

### Benefits of the Service Layer
```ts
// 1. Testable without HTTP
describe('InvoiceService', () => {
  it('calculates tax correctly', async () => {
    const invoice = await invoiceService.create({
      customerId: testCustomerId,
      lineItems: [{ qty: 2, price: 50, description: 'Widget' }],
    }, testUserId);

    expect(invoice.taxCents).toBe(850); // 8.5% of $100
  });
});

// 2. Reusable from a background job
async function processScheduledInvoices() {
  for (const template of scheduledTemplates) {
    await invoiceService.create(template.input, template.userId);
  }
}

// 3. Reusable from a CLI script
// scripts/seed-invoices.ts
await invoiceService.create(testData, adminUserId);
```

### Route Handler Responsibilities (Only These)
```ts
export async function POST(req: Request) {
  // 1. Parse authentication/session
  const session = await requireSession(req);

  // 2. Parse and validate request body (use Zod)
  const body = await parseBody(req, schema);

  // 3. Call service
  const result = await service.doSomething(body, session);

  // 4. Return HTTP response
  return Response.json(result, { status: 201 });
}
```

### Error Handling in the Route Layer
```ts
// Centralized error translation — route handler calls this
function toHttpResponse(err: unknown): Response {
  if (err instanceof ValidationError) {
    return Response.json({ errors: err.errors }, { status: 422 });
  }
  if (err instanceof NotFoundError) {
    return Response.json({ error: err.message }, { status: 404 });
  }
  if (err instanceof ForbiddenError) {
    return Response.json({ error: err.message }, { status: 403 });
  }
  console.error('Unhandled error:', err);
  return Response.json({ error: 'Internal server error' }, { status: 500 });
}

export async function POST(req: Request) {
  try {
    const session = await requireSession(req);
    const body = await parseBody(req, schema);
    const result = await service.create(body, session.userId);
    return Response.json(result, { status: 201 });
  } catch (err) {
    return toHttpResponse(err);
  }
}
```

## Key Rules
- Route handlers must not contain business logic — they translate HTTP requests to service calls and HTTP responses.
- The service layer must not import HTTP types (Request, Response, headers) — it must be callable from non-HTTP contexts.
- Business rules belong in the service, not in request validation schemas — "customer must be in same organization" is business logic.
- Services throw domain errors (`NotFoundError`, `ForbiddenError`) — route handlers translate domain errors to HTTP status codes.
- If a service method needs to be called from both a route handler and a background job, it's correctly placed in the service layer.
- Never query the database directly from a route handler — go through the service layer or repository pattern.
- Thin controllers make service tests authoritative — if the service tests pass, you have confidence the feature works regardless of HTTP layer details.
