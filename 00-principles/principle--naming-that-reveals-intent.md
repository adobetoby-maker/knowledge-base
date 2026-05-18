# Naming That Reveals Intent

## The Rule

Names should reveal WHY and WHAT, not HOW. If you need a comment to explain a name, the name is wrong.

## Variables: Name the Domain Concept

```typescript
// BAD — implementation details:
const x = invoice.lineItems.reduce((a, b) => a + b.price * b.qty, 0)
const filtered = data.filter(r => r.status !== 'deleted')
const arr2 = arr.slice(0, 5)

// GOOD — domain concepts:
const subtotalCents = invoice.lineItems.reduce((sum, item) => sum + item.priceCents * item.quantity, 0)
const activeCustomers = customers.filter(c => c.deletedAt === null)
const recentInvoices = invoices.slice(0, 5)
```

## Functions: Name the Action, Not the Implementation

```typescript
// BAD — describes implementation:
function processData(data) {}
function handleClick() {}
function doStuff() {}
function runQuery() {}

// GOOD — describes the domain action:
function calculateInvoiceTotal(lineItems: LineItem[]): number {}
function submitInvoiceForPayment(invoiceId: string): Promise<void> {}
function searchCustomersByName(query: string): Promise<Customer[]> {}
function archiveOverdueInvoices(): Promise<number> {}
```

## Booleans: Name as Questions

```typescript
// BAD — ambiguous:
const loading = true
const disabled = true
const admin = user.role === 'admin'

// GOOD — reads as yes/no question:
const isLoading = true
const isDisabled = true
const isAdmin = user.role === 'admin'
const hasUnpaidInvoices = invoices.some(i => i.status === 'pending')
const canEditInvoice = isAdmin || invoice.status === 'draft'
```

## Avoid Meaningless Words

Words that add no meaning: `data`, `info`, `manager`, `handler`, `util`, `helper`, `process`, `do`, `run`.

```typescript
// BAD:
const userData = await fetchUserData()
const invoiceManager = new InvoiceManager()
const handleInvoiceClick = () => {}
function processPayment() {}
function doValidation() {}

// GOOD — specific:
const profile = await fetchUserProfile()
// (no InvoiceManager class — just functions)
const openInvoiceDetail = () => {}
function chargeCustomerCard() {}
function validatePaymentAmount() {}
```

## Constants: Name the Semantic Meaning

```typescript
// BAD — magic numbers with no semantic meaning:
if (invoice.totalCents > 100000) { /* ... */ }
if (attempts >= 3) { /* ... */ }
setTimeout(fn, 300)

// GOOD — named constants reveal why the number matters:
const MAX_INVOICE_AMOUNT_CENTS = 100_000_00  // $100,000 limit
const MAX_AUTH_RETRY_ATTEMPTS = 3
const SEARCH_DEBOUNCE_MS = 300
```

## Consistent Naming Across the Codebase

Pick one name for a concept and use it everywhere:
- Choose `customer` vs `client` — not both
- Choose `invoice` vs `order` — not both  
- Choose `userId` vs `user_id` vs `uid` — use the convention for the context (camelCase in TS, snake_case in SQL)
- Choose `createdAt` vs `dateCreated` — stick with one

Inconsistency makes code harder to search and reason about. When you find the team using two names for the same thing, rename one.

## Suffix Conventions

Some suffixes carry meaning — use them consistently:

```typescript
// TypeScript:
type InvoiceStatus = 'draft' | 'sent' | 'paid'   // type suffix
interface InvoiceFormValues {}                      // FormValues suffix for RHF
const InvoiceSchema = z.object({})                 // Schema suffix for Zod
const INVOICE_STATUS_LABELS = {} as const          // SCREAMING_SNAKE for constants

// Database columns:
// _id for foreign keys: customer_id, invoice_id
// _at for timestamps: created_at, deleted_at, updated_at
// _cents for money: total_cents, unit_price_cents
// _url for URLs: attachment_url, avatar_url
```
