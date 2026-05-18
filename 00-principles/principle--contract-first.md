# Principle: Contract-First Development

## The Problem

Writing implementation before defining the contract leads to:
- API shapes that don't match what clients need
- Repeated refactoring as consumers discover the API doesn't fit their actual use case
- Tight coupling between layers (implementation details leak into the public interface)
- Types that describe how something works rather than what it promises

## The Principle

Define the interface (types, API shape, function signature) before writing the implementation. The contract is a commitment — it tells every consumer what they can depend on.

## In TypeScript

```ts
// WRONG: define implementation first, derive types from it
function processInvoices(data: any) {
  // ... figure out the shape as you go
}

// RIGHT: define the contract first
interface InvoiceProcessRequest {
  invoiceIds: string[]
  options?: {
    sendEmail?: boolean
    markAsSent?: boolean
  }
}

interface InvoiceProcessResult {
  processed: number
  failed: Array<{ invoiceId: string; error: string }>
}

async function processInvoices(req: InvoiceProcessRequest): Promise<InvoiceProcessResult> {
  // Now implement to satisfy the contract
}
```

The contract clarifies: what goes in, what comes out, what can fail. Writing it first forces you to think about the consumer before the implementation details.

## In API Design

Before writing a Route Handler, define the request and response schema:

```ts
// Define first:
const CreateClientSchema = z.object({
  name: z.string().min(1).max(200),
  email: z.string().email(),
  phone: z.string().regex(/^\+?[\d\s()-]{7,20}$/).optional(),
  notes: z.string().max(1000).optional(),
})

const CreateClientResponse = z.object({
  id: z.string().uuid(),
  name: z.string(),
  created_at: z.string(),
})

// Then implement the handler to match
```

The schema is the contract. If implementing it requires changing the contract, revise the schema first and consciously decide.

## In Database Schema

The database schema is a contract that outlives any individual piece of code. Design it carefully before creating it:

```sql
-- WRONG: create the table, then add columns as you realize you need them
CREATE TABLE clients (id uuid, name text);
ALTER TABLE clients ADD COLUMN email text;
ALTER TABLE clients ADD COLUMN phone text;
-- ... iterating without a plan

-- RIGHT: think through the full contract before writing DDL
-- What attributes does a client have?
-- What constraints are invariants of the domain?
-- What will queries need to JOIN or filter on?
CREATE TABLE clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text,
  phone text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
```

Additive changes to a schema are safe. Removing or renaming columns in production requires migrations. Design for the full use case upfront.

## In Component Props

```tsx
// WRONG: add props as implementation reveals the need
function InvoiceCard(props: any) { ... }

// RIGHT: define the prop contract before writing JSX
interface InvoiceCardProps {
  invoice: Pick<Invoice, 'id' | 'number' | 'client_name' | 'total_cents' | 'status' | 'issue_date'>
  onView?: (id: string) => void
  onEdit?: (id: string) => void
  compact?: boolean
}

function InvoiceCard({ invoice, onView, onEdit, compact = false }: InvoiceCardProps) { ... }
```

The `Pick` tells readers exactly which invoice fields this component depends on. Adding a new field requires an explicit decision.

## Contract vs Implementation Changes

When the contract must change:
1. Update the TypeScript types/Zod schemas first
2. Let TypeScript errors guide you to every affected site
3. Update each consumer before merging

When only implementation changes:
- No consumer notification needed
- Tests should still pass
- This is the ideal change — the contract is stable, the internals improve

## For Agent Output Contracts

When defining agent outputs:
```ts
// Define the Zod schema first — this IS the contract
const AgentResultSchema = z.object({
  action: z.enum(['create', 'update', 'skip']),
  entityId: z.string().uuid().optional(),
  reason: z.string(),
})

// Then write the prompt to produce this shape
// Not: write the prompt, then parse whatever comes back
```
