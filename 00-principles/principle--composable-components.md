# Composable Components

## The Principle

Build components that can be assembled together, not monoliths that do everything. A component does ONE thing well.

## Composition Over Props Drilling

When a component needs to pass data through many layers, consider composition:

```typescript
// PROP DRILLING — data passes through Invoice → InvoiceHeader → InvoiceActions → DeleteButton:
function Invoice({ invoice }: { invoice: Invoice }) {
  return (
    <div>
      <InvoiceHeader invoice={invoice} canDelete={invoice.status === 'draft'} />
    </div>
  )
}

function InvoiceHeader({ invoice, canDelete }) {
  return (
    <div>
      <h1>{invoice.invoice_number}</h1>
      <InvoiceActions invoiceId={invoice.id} canDelete={canDelete} />
    </div>
  )
}

// COMPOSITION — each component gets only what it needs:
function InvoicePage({ invoice }: { invoice: Invoice }) {
  return (
    <InvoiceLayout>
      <InvoiceHeader>
        <InvoiceNumber value={invoice.invoice_number} />
        {invoice.status === 'draft' && (
          <DeleteInvoiceButton invoiceId={invoice.id} />
        )}
      </InvoiceHeader>
      <InvoiceBody invoice={invoice} />
    </InvoiceLayout>
  )
}
```

## The `children` Pattern

Components that wrap or lay out other components accept `children`:

```typescript
function Card({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={cn('rounded-lg border bg-card p-6', className)}>
      {children}
    </div>
  )
}

// Compose with Card:
<Card>
  <h2 className="text-xl font-semibold">Total Revenue</h2>
  <p className="text-3xl font-bold mt-2">${total}</p>
</Card>
```

## Slot Components

For more structured composition:

```typescript
function PageLayout({
  header,
  sidebar,
  children,
}: {
  header: React.ReactNode
  sidebar?: React.ReactNode
  children: React.ReactNode
}) {
  return (
    <div className="min-h-screen">
      <header className="border-b">{header}</header>
      <div className="flex">
        {sidebar && <aside className="w-64 border-r">{sidebar}</aside>}
        <main className="flex-1 p-6">{children}</main>
      </div>
    </div>
  )
}

// Usage:
<PageLayout
  header={<AdminNav />}
  sidebar={<AdminSidebar />}
>
  <InvoiceTable />
</PageLayout>
```

## Compound Components (Advanced)

For components that share state but render in different places:

```typescript
// Example: Tabs with shared state
const TabsContext = createContext<TabsContextType>(null!)

function Tabs({ defaultTab, children }: { defaultTab: string; children: React.ReactNode }) {
  const [active, setActive] = useState(defaultTab)
  return (
    <TabsContext.Provider value={{ active, setActive }}>
      {children}
    </TabsContext.Provider>
  )
}

function TabsList({ children }: { children: React.ReactNode }) {
  return <div role="tablist" className="flex border-b">{children}</div>
}

function TabsTrigger({ value, children }: { value: string; children: React.ReactNode }) {
  const { active, setActive } = useContext(TabsContext)
  return (
    <button
      role="tab"
      aria-selected={active === value}
      onClick={() => setActive(value)}
    >
      {children}
    </button>
  )
}

// shadcn already implements this pattern — use it, don't rebuild
```

## When to Split a Component

Split when:
- A component renders more than ~100 lines of JSX
- Part of the component is conditionally rendered and complex
- Part has its own independent state
- Part is reused elsewhere

Don't split when:
- The split would create a component that's only used once and has no clear boundary
- The resulting components are too tightly coupled to be useful separately

## What NOT to Do

```typescript
// WRONG — mega-component that does everything:
function InvoicePage() {
  const [filter, setFilter] = useState('')
  const [sortField, setSortField] = useState('')
  const [sortDir, setSortDir] = useState('asc')
  const [selectedRows, setSelectedRows] = useState([])
  const [deleteModalOpen, setDeleteModalOpen] = useState(false)
  // ... 200 more lines of JSX
}

// RIGHT — each piece composed together:
function InvoicePage() {
  return (
    <>
      <InvoiceFilters />  {/* owns filter state */}
      <InvoiceTable />    {/* owns sort/selection state */}
      <BulkActionBar />   {/* reads selection from context */}
    </>
  )
}
```
