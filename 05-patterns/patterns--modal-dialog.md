# Modal and Dialog Pattern

## shadcn/ui Dialog (Standard Approach)

shadcn/ui's Dialog is built on Radix UI primitives, which handle focus management, keyboard navigation, and accessibility automatically.

```typescript
// components/invoice/delete-invoice-dialog.tsx
'use client'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { useState } from 'react'
import { deleteInvoice } from '@/app/actions/invoices'

interface DeleteInvoiceDialogProps {
  invoiceId: string
  invoiceNumber: string
}

export function DeleteInvoiceDialog({ invoiceId, invoiceNumber }: DeleteInvoiceDialogProps) {
  const [open, setOpen] = useState(false)
  const [isLoading, setIsLoading] = useState(false)

  async function handleDelete() {
    setIsLoading(true)
    try {
      await deleteInvoice(invoiceId)
      setOpen(false)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="destructive" size="sm">Delete</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Delete Invoice {invoiceNumber}?</DialogTitle>
          <DialogDescription>
            This action cannot be undone. The invoice and all associated line items will be permanently deleted.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
          <Button variant="destructive" onClick={handleDelete} disabled={isLoading}>
            {isLoading ? 'Deleting...' : 'Delete Invoice'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
```

## Controlled Dialog (External State)

When the trigger is separate from the dialog (e.g., a table row action):

```typescript
// Parent component controls open state
function InvoiceTable({ invoices }: { invoices: Invoice[] }) {
  const [deleteTarget, setDeleteTarget] = useState<Invoice | null>(null)

  return (
    <>
      <table>
        {invoices.map(invoice => (
          <tr key={invoice.id}>
            <td>{invoice.number}</td>
            <td>
              <Button onClick={() => setDeleteTarget(invoice)}>Delete</Button>
            </td>
          </tr>
        ))}
      </table>

      <DeleteInvoiceDialog
        invoice={deleteTarget}
        onClose={() => setDeleteTarget(null)}
      />
    </>
  )
}

// Dialog takes the target as prop — open when truthy
function DeleteInvoiceDialog({
  invoice,
  onClose,
}: {
  invoice: Invoice | null
  onClose: () => void
}) {
  return (
    <Dialog open={!!invoice} onOpenChange={open => { if (!open) onClose() }}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Delete Invoice {invoice?.number}?</DialogTitle>
        </DialogHeader>
        <DialogFooter>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="destructive">Delete</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
```

## Form Inside Dialog

```typescript
// components/invoice/create-invoice-dialog.tsx
'use client'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger,
} from '@/components/ui/dialog'
import { Form, FormField, FormItem, FormLabel, FormControl, FormMessage } from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { useState } from 'react'

const schema = z.object({
  customer_name: z.string().min(1, 'Customer name is required'),
  amount: z.coerce.number().positive('Amount must be positive'),
})

export function CreateInvoiceDialog({ onCreated }: { onCreated: () => void }) {
  const [open, setOpen] = useState(false)
  const form = useForm({ resolver: zodResolver(schema) })

  async function onSubmit(values: z.infer<typeof schema>) {
    await createInvoice(values)
    form.reset()
    setOpen(false)
    onCreated()
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>New Invoice</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create Invoice</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="customer_name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Customer</FormLabel>
                  <FormControl><Input {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
              <Button type="submit" disabled={form.formState.isSubmitting}>
                {form.formState.isSubmitting ? 'Creating...' : 'Create'}
              </Button>
            </div>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}
```

## Alert Dialog (Destructive Confirmations)

Use `AlertDialog` instead of `Dialog` for irreversible actions — it disables outside-click close:

```typescript
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog'

<AlertDialog>
  <AlertDialogTrigger asChild>
    <Button variant="destructive">Delete Account</Button>
  </AlertDialogTrigger>
  <AlertDialogContent>
    <AlertDialogHeader>
      <AlertDialogTitle>Are you absolutely sure?</AlertDialogTitle>
      <AlertDialogDescription>
        This will permanently delete your account and all data.
      </AlertDialogDescription>
    </AlertDialogHeader>
    <AlertDialogFooter>
      <AlertDialogCancel>Cancel</AlertDialogCancel>
      <AlertDialogAction onClick={handleDelete}>Delete Account</AlertDialogAction>
    </AlertDialogFooter>
  </AlertDialogContent>
</AlertDialog>
```

## Common Mistakes

- **Not resetting form on close** — previous form state shows when dialog reopens; call `form.reset()` in `onOpenChange`
- **Using `<Dialog>` for destructive confirmations** — use `<AlertDialog>` which prevents accidental close
- **No loading state during async action** — user double-clicks if button doesn't show loading
- **Missing `asChild` on trigger** — without `asChild`, Radix wraps the trigger in a `<button>` creating nested buttons
