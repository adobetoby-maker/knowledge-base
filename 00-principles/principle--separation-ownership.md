# Principle: Separation of Ownership

## The Problem

When the same code is responsible for multiple concerns — fetching data AND formatting it AND rendering it AND handling errors — changes in one concern require understanding all others. Features grow entangled. Tests require elaborate mocks. Bugs in one layer corrupt another.

## The Principle

Assign clear ownership to each layer of responsibility. A module should do one thing and own one concern. Other modules consume it through its interface without knowing its internals.

## Data Layer Owns DB Access

```ts
// WRONG: UI component knows about the DB
function InvoiceList() {
  const [invoices, setInvoices] = useState([])
  useEffect(() => {
    supabase.from('invoices')
      .select('id, number, client_name, total_cents, status')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .then(({ data }) => setInvoices(data ?? []))
  }, [userId])
  // ... render
}

// RIGHT: data access is owned by a query function
// lib/invoices.ts
export async function getInvoicesByUser(userId: string) {
  const { data, error } = await supabase
    .from('invoices')
    .select('id, number, client_name, total_cents, status')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })

  if (error) throw error
  return data ?? []
}

// Component owns only display:
function InvoiceList() {
  const { data: invoices } = useQuery({
    queryKey: ['invoices', userId],
    queryFn: () => getInvoicesByUser(userId),
  })
}
```

The component doesn't know the query shape changed. The query function doesn't know how its data is rendered.

## Business Logic Layer Owns Rules

```ts
// WRONG: business rule buried in a UI callback
<Button onClick={async () => {
  if (invoice.status !== 'draft') return
  if (!invoice.line_items.length) return
  const total = invoice.line_items.reduce((sum, item) => sum + item.unit_price_cents * item.quantity, 0)
  await supabase.from('invoices').update({ status: 'sent', total_cents: total }).eq('id', invoice.id)
  await sendInvoiceEmail(invoice.id)
}}>
  Send Invoice
</Button>

// RIGHT: business logic is owned by a function that can be tested
// lib/invoices/send.ts
export async function sendInvoice(invoiceId: string): Promise<void> {
  const invoice = await getInvoice(invoiceId)
  if (invoice.status !== 'draft') throw new Error('Only draft invoices can be sent')
  if (invoice.line_items.length === 0) throw new Error('Cannot send an invoice with no line items')

  const total = calculateInvoiceTotal(invoice.line_items)

  await supabaseAdmin.from('invoices')
    .update({ status: 'sent', total_cents: total })
    .eq('id', invoiceId)

  await sendInvoiceEmailNonBlocking(invoiceId)
}

// Component owns only the trigger:
<Button onClick={() => sendInvoice(invoice.id)}>Send Invoice</Button>
```

Now the business rules can be tested without rendering. The component doesn't know the rules.

## Presentation Layer Owns Display

```tsx
// WRONG: formatting logic in the middle of JSX
<td>{(invoice.total_cents / 100).toFixed(2)}</td>
<td>{new Date(invoice.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}</td>

// RIGHT: formatting is owned by pure functions
// lib/format.ts
export const formatCurrency = (cents: number) =>
  new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(cents / 100)

export const formatDate = (iso: string) =>
  new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })

// Component uses formatters:
<td>{formatCurrency(invoice.total_cents)}</td>
<td>{formatDate(invoice.created_at)}</td>
```

Formatting functions are trivially testable, reusable across components, and don't require rendering to verify.

## Configuration Owns Defaults

```ts
// WRONG: default values scattered in UI props
<Select defaultValue="active" />
<DatePicker maxDate={new Date(2099, 11, 31)} />
<Input maxLength={200} />

// RIGHT: defaults come from a single source of truth
// lib/constants.ts
export const INVOICE_DEFAULTS = {
  status: 'draft' as const,
  payment_terms_days: 30,
  currency: 'USD',
} as const

export const VALIDATION_LIMITS = {
  client_name_max: 200,
  notes_max: 1000,
  line_items_max: 50,
} as const
```

## Signs of Ownership Violations

- Component files over 200 lines (doing too much)
- SQL in component files
- Business rules duplicated across multiple components
- Test requires rendering a component to verify a calculation
- Changing a display format requires touching 5 files
