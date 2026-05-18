# Principle: Validation at the Right Layer

## The Problem

Under-validation: trusting untrusted input, skipping checks in server code because "the client already validated it." Over-validation: duplicating the same validation rules in every function that touches the data, creating brittle, inconsistent rule sets.

## The Architecture

```
Browser form    → client-side validation (UX feedback only — not security)
Route Handler   → server-side validation (the actual security boundary)
Database        → schema constraints (the last line of defense)
Business logic  → domain rules (invariants of your domain)
```

Each layer validates what only it can know. No layer trusts layers above it for security.

## Layer 1: Browser Validation

Browser validation is purely for UX. It gives immediate feedback before the user submits. It has zero security value — it can be bypassed by any HTTP client.

```tsx
// React Hook Form + Zod for browser validation
const schema = z.object({
  email: z.string().email('Invalid email address'),
  amount: z.coerce.number().positive('Amount must be positive'),
})

const form = useForm<z.infer<typeof schema>>({
  resolver: zodResolver(schema),
})

// This runs in the browser only — never skip server validation
```

## Layer 2: Server Validation (Security Boundary)

Every Route Handler and Server Action must validate inputs independently of any client-side validation:

```ts
// app/api/invoices/route.ts
export async function POST(request: NextRequest) {
  // 1. Auth — who is calling?
  const session = await validateAdminSession(request)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  // 2. Parse — what did they send?
  let body: unknown
  try {
    body = await request.json()
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 })
  }

  // 3. Validate — is it the right shape?
  const result = CreateInvoiceSchema.safeParse(body)
  if (!result.success) {
    return NextResponse.json(
      { error: 'Validation failed', issues: result.error.flatten().fieldErrors },
      { status: 422 }
    )
  }

  // 4. Business rules — does it satisfy domain constraints?
  if (result.data.items.length === 0) {
    return NextResponse.json({ error: 'Invoice must have at least one line item' }, { status: 422 })
  }

  // 5. Proceed with validated data
  const invoice = await createInvoice(result.data)
  return NextResponse.json(invoice, { status: 201 })
}
```

Never call `body.email` directly from `request.json()` without parsing through a schema first.

## Layer 3: Database Constraints

Database constraints are the last defense — they catch bugs in application code:

```sql
-- Even if application code has a bug, DB enforces invariants
CREATE TABLE invoices (
  status text NOT NULL CHECK (status IN ('draft', 'sent', 'paid', 'cancelled', 'overdue')),
  total_cents integer NOT NULL CHECK (total_cents >= 0),
  due_date date CHECK (due_date IS NULL OR due_date >= issue_date),
  number text UNIQUE NOT NULL
);

-- Foreign keys prevent orphaned records
ALTER TABLE line_items ADD CONSTRAINT fk_invoice
  FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE;
```

If application code tries to insert an invalid status, the DB throws. This is good — it surfaces bugs in development.

## Layer 4: Business Logic Validation

Business rules are domain-specific and belong in your business logic layer:

```ts
// These rules aren't schema constraints — they're domain knowledge
export function validateInvoiceForSending(invoice: Invoice): string[] {
  const errors: string[] = []

  if (invoice.status !== 'draft') {
    errors.push('Only draft invoices can be sent')
  }
  if (invoice.line_items.length === 0) {
    errors.push('Cannot send an invoice with no line items')
  }
  if (!invoice.client_email) {
    errors.push('Client email address is required to send')
  }
  if (invoice.total_cents <= 0) {
    errors.push('Invoice total must be greater than zero')
  }

  return errors
}
```

These rules encode your business logic, not data shape. They belong in `lib/invoices/` alongside the domain model, not in Route Handlers.

## What NOT to Validate

Don't add validation for scenarios that can't happen given the code structure:
- Don't validate that a Server Component returns a string when TypeScript already enforces it
- Don't validate that a Supabase response has the right shape — the TypeScript types cover this
- Don't validate internal function arguments when you control all call sites

Validation at every boundary creates noise. Validate at trust boundaries: between systems, between user input and your code, at external API calls.
