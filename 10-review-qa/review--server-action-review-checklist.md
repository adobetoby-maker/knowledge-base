# Server Action Review Checklist

## Auth Verification

- [ ] Every mutation Server Action verifies auth before any DB operation
- [ ] Admin actions use `validateAdminSession()` (cookie auth)
- [ ] Portal actions use `supabase.auth.getUser()` (Supabase JWT)
- [ ] NEVER uses `supabase.auth.getSession()` — trusts client-controlled cookie

```typescript
// Admin Server Action template:
'use server'
import { validateAdminSession } from '@/lib/adminAuth'
import { revalidatePath } from 'next/cache'

export async function deleteInvoice(id: string): Promise<{ success: boolean; error?: string }> {
  // Step 1: Auth — always first:
  await validateAdminSession()  // throws if not authenticated
  
  // Step 2: Validate input:
  if (!id || typeof id !== 'string') {
    return { success: false, error: 'Invalid invoice ID' }
  }
  
  // Step 3: DB operation:
  const { error } = await supabase.from('invoices').delete().eq('id', id)
  if (error) {
    console.error('Delete invoice error:', error)
    return { success: false, error: 'Failed to delete invoice' }
  }
  
  // Step 4: Revalidate:
  revalidatePath('/admin/invoices')
  
  return { success: true }
}
```

## Input Validation

- [ ] All parameters validated with Zod before use
- [ ] No raw user input passed directly to DB queries
- [ ] ID parameters validated as UUID format
- [ ] Numeric inputs coerced from strings (form data comes as strings)

## Return Type

- [ ] Returns `{ success: boolean; error?: string }` (not throws, except auth failures)
- [ ] Error messages are user-friendly (not internal error codes)
- [ ] Success path returns data when client needs it
- [ ] Type is explicit (not inferred as `Promise<any>`)

## Cache Invalidation

- [ ] `revalidatePath` called for all affected routes after mutation
- [ ] `revalidateTag` used when multiple routes share a tag
- [ ] Paths being revalidated actually correspond to the changed data

```typescript
// After creating invoice:
revalidatePath('/admin/invoices')
revalidatePath(`/invoice/${id}`)  // public invoice view
revalidatePath('/admin/dashboard')  // if dashboard shows invoice count
```

## Supabase Client Usage

- [ ] Uses server client (`lib/supabase/server.ts`), not browser client
- [ ] Admin operations use admin client (`lib/supabase/admin.ts`)
- [ ] Admin client not imported in files that could run client-side

## Error Handling

- [ ] No unhandled promise rejections
- [ ] Database errors logged with context, returned as user-friendly message
- [ ] Auth errors throw (let middleware handle redirect)
- [ ] Validation errors return `{ success: false, error: message }`

## No Access to Request/Response

Server Actions don't have access to Request or Response objects. If you need headers, cookies, or to set response headers — that's a Route Handler, not a Server Action.

```typescript
// WRONG — Server Actions can't access Request:
export async function myAction() {
  'use server'
  const req = useRequest()  // doesn't exist
}

// If you need request access → use a Route Handler instead
```

## 'use server' Placement

```typescript
// CORRECT — directive at top of file (marks whole file as server):
'use server'
export async function myAction() { ... }

// CORRECT — directive inside function body (marks just that function):
export async function myAction() {
  'use server'
  // ...
}

// Prefer file-level for action files, function-level for inline in page components
```
