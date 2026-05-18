# Fail Fast Principle

## Core Rule

Detect problems as early as possible and surface them loudly. The later a bug is caught — dev vs test vs staging vs production — the more expensive it is to fix.

Failing fast means:
- Validate inputs at the boundary, not deep in business logic
- Throw errors on invalid state rather than silently continuing
- Crash early in development; handle gracefully in production

## Boundary Validation

Validate at system boundaries where untrusted data enters. Don't validate deep inside:

```typescript
// GOOD — validate at the Route Handler boundary
export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => null)
  
  const result = createInvoiceSchema.safeParse(body)
  if (!result.success) {
    return NextResponse.json(
      { error: 'Invalid input', details: result.error.flatten().fieldErrors },
      { status: 400 }
    )
  }
  
  // From here, createInvoice() receives validated data and can trust it
  const invoice = await createInvoice(result.data)
  return NextResponse.json(invoice)
}

// BAD — no validation at boundary, error surfaces later
export async function POST(req: NextRequest) {
  const body = await req.json()
  const invoice = await createInvoice(body)  // createInvoice has to defensively check everything
  return NextResponse.json(invoice)
}
```

## Throw, Don't Return null for Impossible States

```typescript
// BAD — silently returns undefined, error surfaces far from the cause
function getInvoiceStatus(invoice: Invoice): string {
  if (invoice.status === 'pending') return 'Pending'
  if (invoice.status === 'paid') return 'Paid'
  // If status is 'refunded', this returns undefined — caller doesn't know why
}

// GOOD — throws immediately when an impossible state occurs
function getInvoiceStatus(invoice: Invoice): string {
  if (invoice.status === 'pending') return 'Pending'
  if (invoice.status === 'paid') return 'Paid'
  if (invoice.status === 'refunded') return 'Refunded'
  throw new Error(`Unexpected invoice status: ${invoice.status}`)
}
```

## Environment Variables: Crash at Startup

```typescript
// BAD — crashes at runtime when first request hits the code
export async function sendEmail(to: string) {
  const apiKey = process.env.RESEND_API_KEY  // might be undefined
  const resend = new Resend(apiKey)          // silently creates broken client
  await resend.emails.send(...)              // fails here, far from the missing env var
}

// GOOD — crashes at startup if env var is missing
function requireEnv(name: string): string {
  const value = process.env[name]
  if (!value) throw new Error(`Missing required environment variable: ${name}`)
  return value
}

const RESEND_API_KEY = requireEnv('RESEND_API_KEY')  // throws at module load time
```

## Assertions in Development

Use assertions to catch logic errors during development:

```typescript
function processInvoiceItems(items: LineItem[]) {
  if (process.env.NODE_ENV === 'development') {
    if (!Array.isArray(items)) throw new Error(`Expected array, got ${typeof items}`)
    if (items.length === 0) throw new Error('Cannot process empty line items')
  }
  
  return items.map(item => ({
    ...item,
    subtotal: item.price * item.quantity,
  }))
}
```

## TypeScript: Exhaustive Checks

Fail at compile time when you forget to handle a new enum value:

```typescript
type InvoiceStatus = 'pending' | 'paid' | 'overdue' | 'cancelled'

function getStatusBadgeColor(status: InvoiceStatus): string {
  switch (status) {
    case 'pending': return 'yellow'
    case 'paid': return 'green'
    case 'overdue': return 'red'
    case 'cancelled': return 'gray'
    default:
      const _exhaustive: never = status  // TypeScript error if a case is missing
      throw new Error(`Unhandled status: ${status}`)
  }
}

// When 'refunded' is added to InvoiceStatus, this switch gets a TypeScript compile error
// The bug is caught at development time, not production runtime
```

## The Development vs Production Distinction

In development: throw loudly, crash hard, show full error details.
In production: catch gracefully at the route level, log the error, return a clean error response.

```typescript
// Development: errors bubble up to Next.js error overlay
// Production: error.tsx catches, logs to monitoring, shows user-friendly message

export default function error({ error }: { error: Error }) {
  // Log to Sentry in production
  captureError(error)
  
  return (
    <div>
      <h2>Something went wrong</h2>
      {process.env.NODE_ENV === 'development' && (
        <pre>{error.message}</pre>
      )}
    </div>
  )
}
```

Fail fast in development so bugs surface during building. Catch gracefully in production so users see helpful messages, not stack traces.
