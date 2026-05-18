# Toast Notification Pattern

## shadcn/ui Sonner Integration

Sonner is the recommended toast library for shadcn/ui projects. It has better defaults than the original shadcn toasts.

```bash
npx shadcn@latest add sonner
```

```typescript
// app/layout.tsx — add Toaster to root layout
import { Toaster } from '@/components/ui/sonner'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        {children}
        <Toaster position="bottom-right" richColors />
      </body>
    </html>
  )
}
```

## Basic Usage

```typescript
'use client'
import { toast } from 'sonner'

// Success
toast.success('Invoice created successfully')

// Error
toast.error('Failed to create invoice')

// Info
toast.info('Invoice sent to customer')

// Warning
toast.warning('Payment overdue by 30 days')

// Loading → then update
const toastId = toast.loading('Creating invoice...')
try {
  await createInvoice(data)
  toast.success('Invoice created', { id: toastId })
} catch (err) {
  toast.error('Failed to create invoice', { id: toastId })
}
```

## After Server Actions

The most common pattern — show feedback after a form submission:

```typescript
// components/invoice/invoice-form.tsx
'use client'
import { useFormState } from 'react-dom'
import { useEffect } from 'react'
import { toast } from 'sonner'
import { createInvoice } from '@/app/actions/invoices'

type ActionState = { success: boolean; message: string } | null

export function InvoiceForm() {
  const [state, formAction] = useFormState<ActionState, FormData>(createInvoice, null)

  useEffect(() => {
    if (state?.success) toast.success(state.message)
    else if (state && !state.success) toast.error(state.message)
  }, [state])

  return (
    <form action={formAction}>
      {/* form fields */}
      <button type="submit">Create Invoice</button>
    </form>
  )
}
```

## After Mutations (TanStack Query)

```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

export function useDeleteInvoice() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (invoiceId: string) =>
      fetch(`/api/invoices/${invoiceId}`, { method: 'DELETE' }).then(r => {
        if (!r.ok) throw new Error('Delete failed')
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
      toast.success('Invoice deleted')
    },
    onError: (err) => {
      toast.error(err.message ?? 'Failed to delete invoice')
    },
  })
}
```

## Toasts with Actions (Undo)

```typescript
function handleDelete(invoiceId: string) {
  // Optimistically remove from UI
  setInvoices(prev => prev.filter(i => i.id !== invoiceId))

  const { dismiss } = toast('Invoice deleted', {
    action: {
      label: 'Undo',
      onClick: () => {
        // Restore the item
        setInvoices(prev => [...prev, deletedInvoice])
        dismiss()
      },
    },
    duration: 5000,
    onDismiss: () => {
      // Actually delete when toast dismisses without undo
      deleteInvoiceOnServer(invoiceId)
    },
  })
}
```

## Custom Toast

```typescript
toast.custom(t => (
  <div className="flex items-center gap-3 rounded-lg border bg-background p-4 shadow-lg">
    <CheckCircle className="h-5 w-5 text-green-500" />
    <div>
      <p className="font-medium">Invoice #1234 sent</p>
      <p className="text-sm text-muted-foreground">Customer will receive it shortly</p>
    </div>
    <button onClick={() => toast.dismiss(t)} className="ml-auto">
      <X className="h-4 w-4" />
    </button>
  </div>
))
```

## Positioning and Configuration

```typescript
// In Toaster component
<Toaster
  position="bottom-right"    // top-left | top-center | top-right | bottom-left | bottom-center | bottom-right
  richColors                 // semantic colors for success/error/warning/info
  expand={false}             // show all toasts expanded (default: false, they stack)
  duration={4000}            // default duration in ms
  closeButton                // show close button on all toasts
  toastOptions={{
    classNames: {
      toast: 'font-sans',
    },
  }}
/>
```

## Common Mistakes

- **Multiple Toaster instances** — only one `<Toaster>` in the app (root layout)
- **Toast in Server Component** — `toast()` is client-only; call from 'use client' components or event handlers
- **No feedback on async operations** — users lose trust when actions complete silently; always confirm success/error
- **Too many info toasts** — only toast on user-initiated actions with meaningful outcomes; don't toast every page transition
- **Very long toast messages** — keep under 60 characters; link to detail page for more info
