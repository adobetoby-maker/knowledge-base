# Naming Conventions

## The Core Standard

Code names are documentation. They describe what the code does so comments don't have to.

A good name makes the code read like a sentence. A bad name forces the reader to look up what something is before they can understand what's happening.

## JavaScript/TypeScript Conventions

### Files and Directories

| Type | Convention | Example |
|------|-----------|---------|
| React components | PascalCase.tsx | `InvoiceCard.tsx` |
| Hooks | use-hook-name.ts | `use-invoice-data.ts` |
| Utilities | kebab-case.ts | `date-format.ts` |
| Constants | SCREAMING_SNAKE.ts | `API_ROUTES.ts` (rare) |
| API routes | Next.js fixed names | `route.ts` |
| Pages | Next.js fixed names | `page.tsx`, `layout.tsx` |

### Variables and Functions

```typescript
// Variables: camelCase, noun or noun phrase
const invoiceCount = 5
const currentUser = await getUser()
const isAuthenticated = !!session

// Functions: camelCase, verb or verb phrase
function calculateTotal(subtotal: number, taxRate: number) {}
async function fetchInvoices(userId: string) {}
function formatCurrency(amount: number) {}

// Event handlers: on + Event or handle + Event
const handleSubmit = (e: FormEvent) => {}
const onStatusChange = (status: string) => {}

// Booleans: is/has/can/should prefix
const isLoading = true
const hasError = false
const canEdit = user.role === 'admin'
const shouldRefetch = staleSince > 5 * 60 * 1000
```

### TypeScript Types and Interfaces

```typescript
// Types and interfaces: PascalCase
interface Invoice { }
type InvoiceStatus = 'pending' | 'paid'
type CreateInvoiceInput = Omit<Invoice, 'id' | 'createdAt'>

// Type parameter: single letter or descriptive word (avoid T alone in complex contexts)
function mapArray<T, U>(items: T[], transform: (item: T) => U): U[]
function fetchResource<TResource>(id: string): Promise<TResource>
```

### Constants

```typescript
// Module-level constants: SCREAMING_SNAKE_CASE
const MAX_INVOICE_AMOUNT = 1_000_000
const DEFAULT_PAGE_SIZE = 20

// Or descriptive camelCase for non-magic-number constants
const sessionCookieName = 'admin_session'
const supabaseStorageBucket = 'blueprints'
```

## Naming Antipatterns to Avoid

### Generic names that tell nothing
```typescript
// BAD
const data = await fetch(url)
const result = processInvoice(invoice)
const temp = user.profile?.name ?? 'Unknown'

// GOOD
const invoiceData = await fetch(url)
const updatedInvoice = processInvoice(invoice)
const displayName = user.profile?.name ?? 'Unknown'
```

### Single-letter variables outside simple loops
```typescript
// BAD
const r = await supabase.from('invoices').select('*')
const u = await supabase.auth.getUser()

// GOOD (readable immediately)
const { data: invoices } = await supabase.from('invoices').select('*')
const { data: { user } } = await supabase.auth.getUser()
```

### Abbreviations that lose meaning
```typescript
// BAD
const inv = await getInvoice(id)  // inv? invoice? inventory?
const usr = currentUser            // usr = user, saves 2 chars, costs clarity

// GOOD
const invoice = await getInvoice(id)
const user = currentUser
```

## Database Naming

```sql
-- Tables: plural, lowercase, underscore
CREATE TABLE invoices (...);
CREATE TABLE line_items (...);
CREATE TABLE user_profiles (...);

-- Columns: lowercase, underscore
created_at TIMESTAMPTZ
user_id UUID
tax_rate DECIMAL(5,2)
is_deleted BOOLEAN  -- boolean columns prefixed with is/has/can

-- Indexes: descriptive, includes table and column
CREATE INDEX idx_invoices_user_id ON invoices(user_id);
CREATE INDEX idx_invoices_status_created ON invoices(status, created_at DESC);
```

## URL Conventions

```
Plural nouns for resources:    /api/invoices
Specific resource:             /api/invoices/:id
Nested resources:              /api/invoices/:id/line-items
Non-CRUD actions (POST):      /api/invoices/:id/send
Pages (kebab-case):            /portal/invoice-history
```
