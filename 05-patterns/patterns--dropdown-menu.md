# Pattern: Dropdown Menu

## What This Solves

Dropdown menus provide contextual actions for list items, table rows, or global commands. Use shadcn/ui DropdownMenu — it handles focus trap, keyboard navigation, and ARIA attributes. The main pattern decision: trigger button style (three-dot icon vs labeled button with chevron).

## Row Action Dropdown (Table)

```tsx
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Button } from '@/components/ui/button'
import { MoreHorizontal, Edit, Copy, Trash2, ExternalLink } from 'lucide-react'

interface RowActionsProps {
  invoiceId: string
  onEdit: () => void
  onDuplicate: () => void
  onDelete: () => void
}

export function RowActions({ invoiceId, onEdit, onDuplicate, onDelete }: RowActionsProps) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className="h-8 w-8"
          aria-label="Row actions"
        >
          <MoreHorizontal className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={onEdit}>
          <Edit className="h-4 w-4 mr-2" />
          Edit invoice
        </DropdownMenuItem>
        <DropdownMenuItem onClick={onDuplicate}>
          <Copy className="h-4 w-4 mr-2" />
          Duplicate
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <a href={`/invoices/${invoiceId}/preview`} target="_blank">
            <ExternalLink className="h-4 w-4 mr-2" />
            Preview
          </a>
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem
          onClick={onDelete}
          className="text-destructive focus:text-destructive"
        >
          <Trash2 className="h-4 w-4 mr-2" />
          Delete
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
```

## Labeled Trigger (Header-Level)

```tsx
<DropdownMenu>
  <DropdownMenuTrigger asChild>
    <Button variant="outline">
      Actions
      <ChevronDown className="h-4 w-4 ml-2" />
    </Button>
  </DropdownMenuTrigger>
  <DropdownMenuContent>
    <DropdownMenuItem>Export CSV</DropdownMenuItem>
    <DropdownMenuItem>Print</DropdownMenuItem>
    <DropdownMenuSeparator />
    <DropdownMenuItem className="text-destructive">Archive all</DropdownMenuItem>
  </DropdownMenuContent>
</DropdownMenu>
```

## With Keyboard Shortcut Hints

```tsx
import { DropdownMenuShortcut } from '@/components/ui/dropdown-menu'

<DropdownMenuItem onClick={onEdit}>
  <Edit className="h-4 w-4 mr-2" />
  Edit
  <DropdownMenuShortcut>⌘E</DropdownMenuShortcut>
</DropdownMenuItem>
```

## With Labels and Sub-Sections

```tsx
import {
  DropdownMenuLabel,
  DropdownMenuGroup,
} from '@/components/ui/dropdown-menu'

<DropdownMenuContent>
  <DropdownMenuLabel>My Account</DropdownMenuLabel>
  <DropdownMenuGroup>
    <DropdownMenuItem>Profile</DropdownMenuItem>
    <DropdownMenuItem>Settings</DropdownMenuItem>
  </DropdownMenuGroup>
  <DropdownMenuSeparator />
  <DropdownMenuLabel>Danger</DropdownMenuLabel>
  <DropdownMenuItem className="text-destructive">Delete account</DropdownMenuItem>
</DropdownMenuContent>
```

## Conditional Items

```tsx
<DropdownMenuContent>
  {invoice.status === 'draft' && (
    <DropdownMenuItem onClick={onSend}>Send to client</DropdownMenuItem>
  )}
  {invoice.status === 'sent' && (
    <DropdownMenuItem onClick={onMarkPaid}>Mark as paid</DropdownMenuItem>
  )}
  {['draft', 'sent'].includes(invoice.status) && (
    <DropdownMenuItem onClick={onCancel}>Cancel invoice</DropdownMenuItem>
  )}
</DropdownMenuContent>
```

## Async Action in Menu Item

```tsx
const [loading, setLoading] = useState<string | null>(null)

<DropdownMenuItem
  onClick={async () => {
    setLoading('send')
    try {
      await sendInvoice(invoice.id)
      toast.success('Invoice sent')
    } finally {
      setLoading(null)
    }
  }}
  disabled={loading !== null}
>
  {loading === 'send' ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <Send className="h-4 w-4 mr-2" />}
  Send invoice
</DropdownMenuItem>
```

## Stopping Propagation

In tables where clicking the row also navigates, stop the dropdown trigger from propagating:

```tsx
<DropdownMenuTrigger asChild>
  <Button
    variant="ghost"
    size="icon"
    onClick={e => e.stopPropagation()}  // Don't trigger row click
  >
    <MoreHorizontal className="h-4 w-4" />
  </Button>
</DropdownMenuTrigger>
```
