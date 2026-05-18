# dnd-kit (Drag and Drop)

## When to Use

Use `@dnd-kit/core` for:
- Sortable lists (reorder invoice line items, reorder tasks)
- Drag-and-drop kanban boards
- File upload with drag-and-drop zones (though react-dropzone is simpler for file upload only)

Do NOT use react-beautiful-dnd (deprecated) or HTML5 drag API (inconsistent behavior).

```bash
npm install @dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities
```

## Sortable List

```typescript
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
} from '@dnd-kit/core'
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  verticalListSortingStrategy,
  useSortable,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'

interface SortableItemProps {
  id: string
  children: React.ReactNode
}

function SortableItem({ id, children }: SortableItemProps) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id })
  
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  }
  
  return (
    <div ref={setNodeRef} style={style} {...attributes}>
      <div className="flex items-center gap-2">
        <button {...listeners} className="cursor-grab active:cursor-grabbing p-1">
          <GripVertical className="h-4 w-4 text-muted-foreground" />
        </button>
        {children}
      </div>
    </div>
  )
}

function SortableList<T extends { id: string }>({
  items,
  onReorder,
  renderItem,
}: {
  items: T[]
  onReorder: (items: T[]) => void
  renderItem: (item: T) => React.ReactNode
}) {
  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
  )
  
  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (!over || active.id === over.id) return
    
    const oldIndex = items.findIndex(i => i.id === active.id)
    const newIndex = items.findIndex(i => i.id === over.id)
    onReorder(arrayMove(items, oldIndex, newIndex))
  }
  
  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
      <SortableContext items={items.map(i => i.id)} strategy={verticalListSortingStrategy}>
        <div className="space-y-1">
          {items.map(item => (
            <SortableItem key={item.id} id={item.id}>
              {renderItem(item)}
            </SortableItem>
          ))}
        </div>
      </SortableContext>
    </DndContext>
  )
}
```

## Usage

```typescript
function InvoiceLineItems() {
  const [items, setItems] = useState<LineItem[]>(initialItems)
  
  return (
    <SortableList
      items={items}
      onReorder={setItems}
      renderItem={(item) => (
        <div className="flex gap-2 p-2 border rounded">
          <span className="flex-1">{item.description}</span>
          <span>{formatCurrency(item.totalCents)}</span>
        </div>
      )}
    />
  )
}
```

## Persisting Sort Order

Store sort order as an integer column:

```sql
ALTER TABLE line_items ADD COLUMN sort_order integer DEFAULT 0;
```

```typescript
// After reorder, save the new order:
async function saveLineItemOrder(items: LineItem[]) {
  const updates = items.map((item, index) => ({
    id: item.id,
    sort_order: index,
  }))
  
  // Batch update via upsert:
  await supabase.from('line_items').upsert(updates, { onConflict: 'id' })
}
```

## Drag Overlay (Floating Preview)

For visual feedback during drag, use DragOverlay:

```typescript
import { DragOverlay } from '@dnd-kit/core'

const [activeId, setActiveId] = useState<string | null>(null)
const activeItem = items.find(i => i.id === activeId)

<DndContext
  onDragStart={({ active }) => setActiveId(active.id as string)}
  onDragEnd={(event) => { handleDragEnd(event); setActiveId(null) }}
  onDragCancel={() => setActiveId(null)}
>
  ...
  <DragOverlay>
    {activeItem ? <ItemPreview item={activeItem} /> : null}
  </DragOverlay>
</DndContext>
```
