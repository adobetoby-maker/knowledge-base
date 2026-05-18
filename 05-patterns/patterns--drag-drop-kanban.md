# Drag-Drop Kanban Board

## When to Use

Use a kanban board when users need to visually manage items across status categories by dragging — task boards, invoice pipelines, CRM stages.

This pattern uses `@dnd-kit/core` with a multi-container approach.

## Data Model

```typescript
// Status is the column:
type InvoiceStatus = 'draft' | 'sent' | 'pending' | 'paid' | 'overdue'

interface Column {
  id: InvoiceStatus
  title: string
  color: string
}

const COLUMNS: Column[] = [
  { id: 'draft', title: 'Draft', color: 'gray' },
  { id: 'sent', title: 'Sent', color: 'blue' },
  { id: 'pending', title: 'Pending', color: 'yellow' },
  { id: 'paid', title: 'Paid', color: 'green' },
  { id: 'overdue', title: 'Overdue', color: 'red' },
]
```

## Kanban Component

```typescript
import { DndContext, DragOverlay, closestCenter, DragStartEvent, DragEndEvent } from '@dnd-kit/core'
import { SortableContext, verticalListSortingStrategy } from '@dnd-kit/sortable'

function KanbanBoard({ invoices, onStatusChange }: {
  invoices: Invoice[]
  onStatusChange: (invoiceId: string, newStatus: InvoiceStatus) => void
}) {
  const [activeInvoice, setActiveInvoice] = useState<Invoice | null>(null)
  
  // Group invoices by status:
  const columns = useMemo(() => {
    const grouped = new Map<InvoiceStatus, Invoice[]>()
    COLUMNS.forEach(col => grouped.set(col.id, []))
    invoices.forEach(inv => {
      grouped.get(inv.status as InvoiceStatus)?.push(inv)
    })
    return grouped
  }, [invoices])
  
  function handleDragStart({ active }: DragStartEvent) {
    const invoice = invoices.find(i => i.id === active.id)
    setActiveInvoice(invoice ?? null)
  }
  
  function handleDragEnd({ active, over }: DragEndEvent) {
    setActiveInvoice(null)
    if (!over) return
    
    // over.id is either a column id or another invoice id:
    const targetStatus = COLUMNS.find(c => c.id === over.id)?.id
      ?? invoices.find(i => i.id === over.id)?.status as InvoiceStatus | undefined
    
    if (targetStatus && targetStatus !== activeInvoice?.status) {
      onStatusChange(String(active.id), targetStatus)
    }
  }
  
  return (
    <DndContext
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
      collisionDetection={closestCenter}
    >
      <div className="flex gap-4 overflow-x-auto pb-4">
        {COLUMNS.map(column => (
          <KanbanColumn
            key={column.id}
            column={column}
            invoices={columns.get(column.id) ?? []}
          />
        ))}
      </div>
      
      <DragOverlay>
        {activeInvoice && <InvoiceCard invoice={activeInvoice} isDragOverlay />}
      </DragOverlay>
    </DndContext>
  )
}

function KanbanColumn({ column, invoices }: { column: Column; invoices: Invoice[] }) {
  const { setNodeRef } = useDroppable({ id: column.id })
  
  return (
    <div className="flex flex-col w-64 min-w-64">
      <div className="flex items-center gap-2 mb-2">
        <div className={cn('w-2 h-2 rounded-full', `bg-${column.color}-500`)} />
        <h3 className="font-medium text-sm">{column.title}</h3>
        <Badge variant="outline" className="ml-auto">{invoices.length}</Badge>
      </div>
      
      <div ref={setNodeRef} className="flex-1 space-y-2 min-h-[100px] p-1 rounded-lg bg-muted/50">
        <SortableContext items={invoices.map(i => i.id)} strategy={verticalListSortingStrategy}>
          {invoices.map(invoice => (
            <SortableInvoiceCard key={invoice.id} invoice={invoice} />
          ))}
        </SortableContext>
      </div>
    </div>
  )
}
```

## Persisting Status Changes

```typescript
// Optimistic update + server sync:
function useKanban(initialInvoices: Invoice[]) {
  const [invoices, setInvoices] = useState(initialInvoices)
  const queryClient = useQueryClient()
  
  const mutation = useMutation({
    mutationFn: ({ invoiceId, status }: { invoiceId: string; status: InvoiceStatus }) =>
      updateInvoiceStatus(invoiceId, status),
    onMutate: async ({ invoiceId, status }) => {
      // Optimistic update:
      setInvoices(prev => prev.map(inv =>
        inv.id === invoiceId ? { ...inv, status } : inv
      ))
    },
    onError: () => {
      // Rollback:
      setInvoices(initialInvoices)
      toast.error('Failed to update status')
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
    },
  })
  
  return {
    invoices,
    handleStatusChange: (invoiceId: string, status: InvoiceStatus) =>
      mutation.mutate({ invoiceId, status }),
  }
}
```
