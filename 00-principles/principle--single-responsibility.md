# Principle: Single Responsibility

## What It Is

A function, class, or module should have one reason to change. If it changes when the business logic changes AND when the data format changes AND when the UI requirements change, it's doing too many things.

Single responsibility is narrower than separation of concerns — it's about the rate of change, not just the category of work.

## Identifying Violations

A function is doing too much when:
- Its name contains "and" or "or" (`fetchAndProcessInvoices`)
- It's longer than 40-50 lines
- It needs comments to explain what each section does
- Testing it requires setting up 3+ mocks
- A change to the output format also requires changing the business logic

## Practical Examples

### Route Handler That Does Too Much

```ts
// WRONG — one function handles auth, validation, DB, email, and response formatting
export async function POST(req: Request) {
  // 1. Auth
  const token = req.headers.get('Authorization')?.split(' ')[1]
  if (!token) return new Response('Unauthorized', { status: 401 })
  const { userId } = await verifyJWT(token)

  // 2. Parse and validate
  const body = await req.json()
  if (!body.email || !body.amount) return Response.json({ error: 'Missing fields' }, { status: 400 })

  // 3. Business logic
  const invoice = { userId, email: body.email, amount: body.amount, status: 'pending' }

  // 4. Database
  const { data } = await supabase.from('invoices').insert(invoice).select().single()

  // 5. Email
  await sendEmail({ to: body.email, subject: 'Invoice created', body: `Invoice #${data.id}` })

  // 6. Return
  return Response.json({ id: data.id })
}
```

Each section has a different reason to change. Email template changes shouldn't touch auth logic.

```ts
// CORRECT — each function has one responsibility
export async function POST(req: Request) {
  const user = await authenticateRequest(req)  // Changes when auth strategy changes
  const data = await parseCreateInvoice(req)   // Changes when schema changes
  const invoice = await createInvoice(user.id, data)  // Changes when business rules change
  await notifyInvoiceCreated(invoice)          // Changes when notification strategy changes
  return Response.json({ id: invoice.id })
}
```

## Component Responsibility

```tsx
// WRONG — one component does pagination, filtering, rendering, and data fetching
function ProductListPage() {
  const [page, setPage] = useState(1)
  const [category, setCategory] = useState('all')
  const [products, setProducts] = useState([])
  // ... 80 lines of mixed concerns
}

// CORRECT — each component does one thing
function ProductListPage() {
  return (
    <FilterableProductList
      renderFilters={(filters) => <ProductFilters {...filters} />}
      renderProducts={(products, paging) => (
        <>
          <ProductGrid products={products} />
          <Pagination {...paging} />
        </>
      )}
    />
  )
}
```

## Hook Responsibility

```ts
// WRONG — one hook manages both data fetching and UI state
function useProductListPage() {
  const [page, setPage] = useState(1)
  const [category, setCategory] = useState('all')
  const [showFilters, setShowFilters] = useState(false)  // UI state
  const [products, setProducts] = useState([])           // Server state

  useEffect(() => {
    fetch(`/api/products?page=${page}&category=${category}`).then(...)
  }, [page, category])
}

// CORRECT — separate concerns
function useProductFilters() {
  const [category, setCategory] = useState('all')
  const [showFilters, setShowFilters] = useState(false)
  return { category, setCategory, showFilters, setShowFilters }
}

function useProducts(filters: ProductFilters) {
  return useQuery(['products', filters], () => fetchProducts(filters))
}
```

## Utility Functions

```ts
// WRONG — one function reads, transforms, and writes
async function processUserExport(userId: string) {
  const data = await supabase.from('users').select('*').eq('id', userId).single()
  const csv = Object.entries(data).map(([k, v]) => `${k},${v}`).join('\n')
  await fs.writeFile(`export-${userId}.csv`, csv)
}

// CORRECT — separated concerns, each reusable
async function fetchUserData(userId: string) { ... }
function formatAsCSV(record: Record<string, unknown>) { ... }
async function writeExportFile(path: string, content: string) { ... }

async function processUserExport(userId: string) {
  const data = await fetchUserData(userId)
  const csv = formatAsCSV(data)
  await writeExportFile(`export-${userId}.csv`, csv)
}
```

## The Test Signal

If a unit test for function X requires you to set up mocks for Y and Z (unrelated things), X is doing too much. Aim for tests that need at most one mock setup.
