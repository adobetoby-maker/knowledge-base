# Principle: Contract-First Development

## Overview
A contract is an explicit, shared agreement between two parties about what data passes between them. In software: the API schema between frontend and backend, the event schema between services, the database schema between the application and storage. Contract-first means defining this agreement before writing the implementations. Code-first schema generation (deriving types from whatever the code happens to return) produces implicit contracts that are not versioned, not shared, and change without coordination. Explicit contracts enable parallel work, automated testing, and deliberate versioning.

## Implementation

### API Contract with Zod (TypeScript)
```ts
// contracts/invoices.ts — the shared contract, imported by both client and server
import { z } from 'zod';

export const LineItemSchema = z.object({
  description: z.string().min(1),
  quantity: z.number().int().positive(),
  unitPriceCents: z.number().int().nonneg(),
});

export const CreateInvoiceRequest = z.object({
  customerId: z.string().uuid(),
  lineItems: z.array(LineItemSchema).min(1),
  dueDate: z.string().datetime().optional(),
  notes: z.string().max(1000).optional(),
});

export const InvoiceResponse = z.object({
  id: z.string().uuid(),
  customerId: z.string().uuid(),
  lineItems: z.array(LineItemSchema.extend({ id: z.string().uuid() })),
  subtotalCents: z.number().int(),
  taxCents: z.number().int(),
  totalCents: z.number().int(),
  status: z.enum(['draft', 'sent', 'paid', 'overdue']),
  createdAt: z.string().datetime(),
  dueDate: z.string().datetime().nullable(),
});

// Derive TypeScript types from the schema
export type CreateInvoiceInput = z.infer<typeof CreateInvoiceRequest>;
export type Invoice = z.infer<typeof InvoiceResponse>;
```

### Server Uses the Contract
```ts
// Server validates incoming requests against the contract
import { CreateInvoiceRequest } from '@/contracts/invoices';

export async function POST(req: Request) {
  const body = await req.json();
  const parsed = CreateInvoiceRequest.safeParse(body);

  if (!parsed.success) {
    return Response.json(
      { errors: parsed.error.flatten().fieldErrors },
      { status: 422 }
    );
  }

  const invoice = await invoiceService.create(parsed.data, session.userId);

  // Validate response against contract before sending
  const validated = InvoiceResponse.parse(invoice);
  return Response.json(validated, { status: 201 });
}
```

### Client Uses the Same Contract
```ts
// Client imports the same contract — types are always in sync
import { Invoice, CreateInvoiceInput } from '@/contracts/invoices';

async function createInvoice(input: CreateInvoiceInput): Promise<Invoice> {
  const res = await fetch('/api/invoices', {
    method: 'POST',
    body: JSON.stringify(input),
    headers: { 'Content-Type': 'application/json' },
  });

  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json() as Promise<Invoice>;
}
```

### OpenAPI for Cross-Language Contracts
When client and server are in different languages:
```yaml
# openapi.yaml — language-neutral contract
openapi: 3.1.0
paths:
  /invoices:
    post:
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateInvoiceRequest'
      responses:
        '201':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Invoice'

components:
  schemas:
    CreateInvoiceRequest:
      type: object
      required: [customerId, lineItems]
      properties:
        customerId:
          type: string
          format: uuid
        lineItems:
          type: array
          minItems: 1
          items:
            $ref: '#/components/schemas/LineItem'
```

Generate types from this spec:
- TypeScript: `npx openapi-typescript openapi.yaml -o types/api.ts`
- Python: `openapi-generator-cli generate -i openapi.yaml -g python`

### Event Schema Contract
```ts
// contracts/events.ts
export const OrderCreatedEvent = z.object({
  type: z.literal('order.created'),
  version: z.literal('1.0'),
  payload: z.object({
    orderId: z.string().uuid(),
    userId: z.string().uuid(),
    totalCents: z.number().int(),
    lineItems: z.array(z.object({
      productId: z.string().uuid(),
      quantity: z.number().int(),
    })),
  }),
  metadata: z.object({
    timestamp: z.string().datetime(),
    correlationId: z.string().uuid(),
  }),
});
```

### Contract Testing (Pact)
```ts
// Pact contract test — ensures provider still matches what consumer expects
describe('Invoice API contract', () => {
  it('returns an invoice matching the contract', async () => {
    const actual = await api.getInvoice('test-id');
    const result = InvoiceResponse.safeParse(actual);
    expect(result.success).toBe(true);
  });
});
```

## Key Rules
- Define the contract before writing client or server code — not after the fact from whatever the code returns.
- Single source of truth: the contract schema file is shared between client and server, not duplicated.
- Contract changes must be versioned — a field removal is a breaking change that requires a new contract version.
- Validate responses against the contract schema, not just requests — contract violations can originate on either side.
- Code-first schema generation (deriving types from ORM models) produces implicit contracts — acceptable for internal use only, not for cross-team or cross-system contracts.
- When contracts change, update both sides atomically or use a compatibility period — never assume both sides update simultaneously.
- OpenAPI is the standard for cross-language API contracts; Zod/TypeScript types are sufficient for same-language monorepos.
