# React Form Patterns

## Controlled vs Uncontrolled

**Controlled**: React state drives the input value. Every keystroke triggers a state update and re-render.

```typescript
const [email, setEmail] = useState('')
<input value={email} onChange={e => setEmail(e.target.value)} />
```

Use controlled when: you need real-time validation, conditional field visibility, or format-as-you-type behavior.

**Uncontrolled**: DOM drives the value; read it at submission.

```typescript
const formRef = useRef<HTMLFormElement>(null)
const handleSubmit = () => {
  const data = new FormData(formRef.current!)
  const email = data.get('email') as string
}
<form ref={formRef}><input name="email" /></form>
```

Use uncontrolled when: you just need the final values at submit, no real-time processing. Uncontrolled forms are substantially faster for large forms.

## React 19 Server Actions with useActionState

The preferred pattern in Next.js App Router for form submissions:

```typescript
// actions/contact.ts (server action)
'use server'
export async function submitContact(prevState: any, formData: FormData) {
  const email = formData.get('email') as string
  if (!email) return { error: 'Email required' }
  
  await db.contacts.create({ email })
  return { success: true }
}

// components/ContactForm.tsx
'use client'
import { useActionState } from 'react'
import { submitContact } from '../actions/contact'

export function ContactForm() {
  const [state, formAction, isPending] = useActionState(submitContact, null)
  
  return (
    <form action={formAction}>
      <input name="email" type="email" required />
      <button type="submit" disabled={isPending}>
        {isPending ? 'Sending...' : 'Submit'}
      </button>
      {state?.error && <p className="error">{state.error}</p>}
      {state?.success && <p>Sent!</p>}
    </form>
  )
}
```

This handles loading state, error state, and progressive enhancement (works without JavaScript) automatically.

## Zod Validation Pattern

For API route handlers and server actions, validate with Zod at the boundary:

```typescript
import { z } from 'zod'

const ContactSchema = z.object({
  name: z.string().min(2).max(100),
  email: z.string().email(),
  phone: z.string().regex(/^\d{10}$/).optional(),
  message: z.string().min(10).max(1000)
})

// In server action or API route:
const result = ContactSchema.safeParse({
  name: formData.get('name'),
  email: formData.get('email'),
  phone: formData.get('phone'),
  message: formData.get('message')
})

if (!result.success) {
  return { errors: result.error.flatten().fieldErrors }
}

// result.data is fully typed and validated
const { name, email, phone, message } = result.data
```

`safeParse` never throws — it returns `{ success: true, data }` or `{ success: false, error }`. Always use `safeParse` in server actions; use `parse` only when you want to let the exception propagate.

## Displaying Field-Level Errors

```typescript
type FormState = {
  errors?: {
    name?: string[]
    email?: string[]
    message?: string[]
  }
  success?: boolean
}

// In the form
{state?.errors?.email && (
  <p className="text-red-500 text-sm mt-1">{state.errors.email[0]}</p>
)}
```

## Multi-Step Forms

For multi-step forms, store progress in URL params so navigation works:

```typescript
const step = Number(searchParams.get('step') ?? '1')

// On step completion:
router.push(`?step=${step + 1}`)
```

Store the accumulated data in React state during the flow, then submit all at once on the final step. Do not submit partial data between steps unless there is a specific reason (e.g., saving a draft).

## File Upload Pattern

```typescript
async function handleFileUpload(formData: FormData) {
  const file = formData.get('photo') as File
  if (!file || file.size === 0) return { error: 'No file' }
  if (file.size > 5 * 1024 * 1024) return { error: 'File too large (max 5MB)' }
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
    return { error: 'Invalid file type' }
  }
  
  const bytes = await file.arrayBuffer()
  const buffer = Buffer.from(bytes)
  // upload to Supabase Storage or other
}
```

Never trust client-supplied MIME types for security-sensitive operations — verify the actual file magic bytes server-side for truly sensitive uploads.
