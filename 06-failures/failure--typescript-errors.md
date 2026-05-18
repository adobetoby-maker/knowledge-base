# TypeScript Common Errors and Fixes

## 1. Type 'string | null' Not Assignable to 'string'

**Symptom:** `Argument of type 'string | null' is not assignable to parameter of type 'string'`

**Cause:** A value that could be null is used where only string is expected.

```typescript
// ERROR
const status = searchParams.get('status')  // string | null
setFilter(status)  // expects string

// FIX 1: nullish coalescing
const status = searchParams.get('status') ?? 'all'

// FIX 2: type guard
if (status !== null) setFilter(status)

// FIX 3: non-null assertion (only when you're CERTAIN it won't be null)
const status = searchParams.get('status')!  // avoid unless truly certain
```

## 2. Property 'x' Does Not Exist on Type 'y'

**Symptom:** `Property 'line_items' does not exist on type 'Invoice'`

**Cause 1:** The type doesn't include the property (maybe it was added to the DB but not the type).
**Cause 2:** Using a partial type that omits the property.

```typescript
// FIX: update the type definition
interface Invoice {
  id: string
  number: string
  line_items: LineItem[]  // add the missing property
}

// Or: type narrowing if the property is optional
if ('line_items' in invoice && invoice.line_items) {
  // TypeScript knows line_items exists here
}
```

## 3. Cannot Invoke an Object Which Is Possibly 'undefined'

**Symptom:** `Cannot invoke an object which is possibly 'undefined'`

**Cause:** Calling a function stored in state/props that might not be set yet.

```typescript
// ERROR
interface Props {
  onClick?: () => void
}
function Button({ onClick }: Props) {
  return <button onClick={() => onClick()}>Click</button>  // Error: onClick might be undefined
}

// FIX 1: conditional call
return <button onClick={() => onClick?.()}>Click</button>

// FIX 2: pass directly (onClick is compatible with optional onClick prop)
return <button onClick={onClick}>Click</button>
```

## 4. Async Params TypeScript Error (Next.js 15)

**Symptom:** `Property 'slug' does not exist on type 'Promise<{ slug: string }>'`

**Cause:** Next.js 15 changed `params` from `{ slug: string }` to `Promise<{ slug: string }>`.

```typescript
// WRONG (old Next.js 14 syntax):
export default function Page({ params }: { params: { slug: string } }) {
  const { slug } = params  // Error in Next.js 15
}

// CORRECT (Next.js 15):
export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
}
```

## 5. Type 'ReactNode' Is Not Assignable to Type 'ReactElement'

**Symptom:** Type error when passing `children` to something expecting `ReactElement`.

**Cause:** `ReactNode` includes `null`, `undefined`, `string`, `number`, and fragments in addition to `ReactElement`.

```typescript
// ERROR: ReactNode includes null and strings, ReactElement doesn't
function Wrapper({ children }: { children: ReactElement }) {
  return React.cloneElement(children, { className: 'extra' })
}

// FIX: accept ReactElement specifically when you need clone/manipulation
// Use ReactNode when you just need to render (the common case)
function Layout({ children }: { children: React.ReactNode }) {
  return <div>{children}</div>
}
```

## 6. 'never' Type Error

**Symptom:** `Argument of type 'X' is not assignable to parameter of type 'never'`

**Cause:** The union type was exhaustively checked and the value can't be any remaining case.

```typescript
// This is often a DESIRED behavior — exhaustive switch:
function getLabel(status: 'pending' | 'paid' | 'overdue'): string {
  switch (status) {
    case 'pending': return 'Pending'
    case 'paid': return 'Paid'
    case 'overdue': return 'Overdue'
    default:
      // If a new status is added but not handled, this becomes an error:
      const _exhaustive: never = status  // Type error → add a case above
      return ''
  }
}
```

When this error appears unexpectedly, it means a type narrowing path eliminated all possible types. Debug by checking what types lead to that branch.

## 7. Zod Inferred Types

**Symptom:** Type doesn't include optional fields, or includes them all as required.

```typescript
// Zod inferences:
const schema = z.object({
  name: z.string(),              // name: string
  email: z.string().optional(),  // email?: string | undefined
  age: z.number().nullable(),    // age: number | null
})

type FormData = z.infer<typeof schema>
// { name: string; email?: string | undefined; age: number | null }

// Accessing: must handle undefined
const email = data.email ?? ''  // not just data.email
```

## 8. Supabase Response Type

**Symptom:** Supabase query returns `any` type for `data`.

**Fix:** Use generated Supabase types:
```bash
npx supabase gen types typescript --project-id your-project-id > lib/database.types.ts
```

```typescript
import type { Database } from '@/lib/database.types'

const supabase = createClient<Database>()

const { data: invoices } = await supabase
  .from('invoices')
  .select('*')
// invoices is now Database['public']['Tables']['invoices']['Row'][]
```
