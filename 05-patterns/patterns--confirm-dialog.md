# Confirm Dialog Pattern

## The Core Pattern

Use `AlertDialog` from shadcn for any destructive or irreversible action. Never use `window.confirm()` — it blocks the main thread and looks terrible.

```typescript
// components/DeleteInvoiceButton.tsx
'use client'
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
import { Button } from '@/components/ui/button'
import { deleteInvoice } from '@/lib/actions/invoices'
import { useTransition } from 'react'
import { toast } from 'sonner'

export function DeleteInvoiceButton({ invoiceId }: { invoiceId: string }) {
  const [isPending, startTransition] = useTransition()
  
  function handleDelete() {
    startTransition(async () => {
      const result = await deleteInvoice(invoiceId)
      if (result.success) {
        toast.success('Invoice deleted')
      } else {
        toast.error(result.error)
      }
    })
  }
  
  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <Button variant="destructive" size="sm">Delete</Button>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Delete this invoice?</AlertDialogTitle>
          <AlertDialogDescription>
            This cannot be undone. The invoice and all payment records will be permanently removed.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancel</AlertDialogCancel>
          <AlertDialogAction
            onClick={handleDelete}
            disabled={isPending}
            className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
          >
            {isPending ? 'Deleting...' : 'Delete invoice'}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}
```

## Reusable Confirm Dialog

Extract a generic confirm dialog for multiple use cases:

```typescript
// components/ConfirmDialog.tsx
interface ConfirmDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  description: string
  confirmLabel?: string
  onConfirm: () => void | Promise<void>
  variant?: 'destructive' | 'default'
  isPending?: boolean
}

export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel = 'Confirm',
  onConfirm,
  variant = 'default',
  isPending = false,
}: ConfirmDialogProps) {
  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{title}</AlertDialogTitle>
          <AlertDialogDescription>{description}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel disabled={isPending}>Cancel</AlertDialogCancel>
          <AlertDialogAction
            onClick={onConfirm}
            disabled={isPending}
            className={variant === 'destructive'
              ? 'bg-destructive text-destructive-foreground hover:bg-destructive/90'
              : undefined
            }
          >
            {isPending ? 'Processing...' : confirmLabel}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}

// Usage:
const [open, setOpen] = useState(false)
const [isPending, startTransition] = useTransition()

<ConfirmDialog
  open={open}
  onOpenChange={setOpen}
  title="Mark as paid?"
  description={`This will record payment of $${invoice.amount}.`}
  confirmLabel="Mark paid"
  onConfirm={() => startTransition(async () => {
    await markPaid(invoice.id)
    setOpen(false)
  })}
  isPending={isPending}
/>
```

## Confirm Before Navigation (Unsaved Changes)

For forms with unsaved changes:

```typescript
// hooks/useUnsavedChangesWarning.ts
export function useUnsavedChangesWarning(isDirty: boolean) {
  useEffect(() => {
    if (!isDirty) return
    
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      e.preventDefault()
    }
    
    window.addEventListener('beforeunload', handleBeforeUnload)
    return () => window.removeEventListener('beforeunload', handleBeforeUnload)
  }, [isDirty])
}

// In form component:
const form = useForm(...)
useUnsavedChangesWarning(form.formState.isDirty)
```

Note: Browser `beforeunload` only shows a generic "Leave site?" message — browsers removed custom messages for security reasons. For in-app navigation (Next.js router), this does NOT intercept — you need a custom confirm dialog triggered before the router action.

## Confirmation Copy Guidelines

- State what will happen: "Delete this invoice?" not "Are you sure?"
- Describe the consequence: "This cannot be undone." when it truly can't
- Make the confirm button match the action: "Delete invoice" not "Yes" or "OK"
- Cancel should be the less visually prominent option
- Don't ask for confirmation on reversible actions — mark paid, send email, etc. are reversible enough to handle with toast + undo
