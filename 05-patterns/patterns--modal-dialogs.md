# Modal Dialog Patterns

## Three Levels of Dialog

1. **AlertDialog** — for destructive/irreversible confirmations
2. **Dialog** — for forms, detail views, selection pickers
3. **Sheet** — for panels that slide in from the side (mobile nav, filter panel, detail view)

## Dialog for Forms

When a form doesn't need its own page (quick add, quick edit):

```typescript
// components/AddCustomerDialog.tsx
'use client'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { useState, useTransition } from 'react'

export function AddCustomerDialog() {
  const [open, setOpen] = useState(false)
  const [isPending, startTransition] = useTransition()
  
  const form = useForm({ resolver: zodResolver(CustomerSchema) })
  
  function onSubmit(data: CustomerFormData) {
    startTransition(async () => {
      const result = await createCustomer(data)
      if (result.success) {
        toast.success('Customer added')
        setOpen(false)
        form.reset()
      } else {
        form.setError('root', { message: result.error })
      }
    })
  }
  
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>
          <Plus className="h-4 w-4 mr-2" />
          Add Customer
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Add Customer</DialogTitle>
        </DialogHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
          <FormField
            control={form.control}
            name="name"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Name</FormLabel>
                <FormControl><Input {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          {form.formState.errors.root && (
            <Alert variant="destructive">
              <AlertDescription>{form.formState.errors.root.message}</AlertDescription>
            </Alert>
          )}
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={isPending}>
              {isPending ? 'Adding...' : 'Add Customer'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
```

## Sheet for Side Panels

For detail views, filter panels, or navigation on mobile:

```typescript
// components/InvoiceDetailSheet.tsx
'use client'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'

export function InvoiceDetailSheet({
  invoice,
  open,
  onOpenChange,
}: {
  invoice: Invoice | null
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="w-[400px] sm:w-[540px]">
        {invoice && (
          <>
            <SheetHeader>
              <SheetTitle>Invoice #{invoice.invoice_number}</SheetTitle>
            </SheetHeader>
            <div className="mt-6 space-y-4">
              <InvoiceDetails invoice={invoice} />
            </div>
          </>
        )}
      </SheetContent>
    </Sheet>
  )
}

// In parent: open on row click
function InvoiceRow({ invoice }: { invoice: Invoice }) {
  const [detailOpen, setDetailOpen] = useState(false)
  
  return (
    <>
      <TableRow className="cursor-pointer" onClick={() => setDetailOpen(true)}>
        {/* ... cells ... */}
      </TableRow>
      <InvoiceDetailSheet
        invoice={invoice}
        open={detailOpen}
        onOpenChange={setDetailOpen}
      />
    </>
  )
}
```

## Focus Management

When a Dialog opens, focus should move inside it (shadcn handles this automatically with `Dialog`). When it closes, focus should return to the trigger element.

```typescript
const triggerRef = useRef<HTMLButtonElement>(null)

// Custom dialog without shadcn:
function closeDialog() {
  setOpen(false)
  // Return focus after state update:
  setTimeout(() => triggerRef.current?.focus(), 0)
}

<button ref={triggerRef} onClick={() => setOpen(true)}>
  Open dialog
</button>
```

## Dialog with Loading State

```typescript
function EditInvoiceDialog({ invoiceId }: { invoiceId: string }) {
  const [open, setOpen] = useState(false)
  const { data: invoice, isLoading } = useQuery({
    queryKey: ['invoice', invoiceId],
    queryFn: () => fetchInvoice(invoiceId),
    enabled: open,  // only fetch when dialog opens
  })
  
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">Edit</Button>
      </DialogTrigger>
      <DialogContent>
        {isLoading ? (
          <div className="flex justify-center py-8">
            <Loader2 className="h-6 w-6 animate-spin" />
          </div>
        ) : invoice ? (
          <EditInvoiceForm invoice={invoice} onSuccess={() => setOpen(false)} />
        ) : null}
      </DialogContent>
    </Dialog>
  )
}
```

`enabled: open` defers the query until the dialog opens — avoids fetching data for every row in the table just in case the user clicks Edit.

## When to Use a Page Instead

Use a dialog when:
- The action is quick (< 3 fields, < 30 seconds)
- The context from the parent view is important
- A full page would feel disproportionate

Use a page when:
- The form has many fields
- The action requires seeing related data (linked invoices, history)
- Users need to share a link directly to this view
- The task might take several minutes
