# Drag and Drop Pattern

## Library Choice

| Use Case | Library |
|---|---|
| Kanban board, card reordering | `@dnd-kit/core` + `@dnd-kit/sortable` |
| File upload drop zone | Native HTML drag API or `react-dropzone` |
| Complex flows (manage-worker-bee blueprint canvas) | `@xyflow/react` |
| Simple list reordering | `@dnd-kit/sortable` |

**@dnd-kit is the current standard** — it's accessible, touch-enabled, and doesn't use deprecated HTML5 DnD API directly.

## Sortable List with @dnd-kit

```bash
npm install @dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities
```

```typescript
'use client'
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
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { useState } from 'react'
import { GripVertical } from 'lucide-react'

// Individual sortable item
function SortableItem({ id, label }: { id: string; label: string }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  }

  return (
    <div
      ref={setNodeRef}
      style={style}
      className="flex items-center gap-3 p-3 bg-card border rounded-md"
    >
      {/* Drag handle */}
      <button
        {...attributes}
        {...listeners}
        className="cursor-grab active:cursor-grabbing text-muted-foreground"
        aria-label="Drag to reorder"
      >
        <GripVertical className="h-4 w-4" />
      </button>
      <span>{label}</span>
    </div>
  )
}

// Sortable list container
export function SortableList() {
  const [items, setItems] = useState([
    { id: '1', label: 'First item' },
    { id: '2', label: 'Second item' },
    { id: '3', label: 'Third item' },
  ])

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,  // keyboard accessibility
    })
  )

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (!over || active.id === over.id) return

    setItems((items) => {
      const oldIndex = items.findIndex((item) => item.id === active.id)
      const newIndex = items.findIndex((item) => item.id === over.id)
      return arrayMove(items, oldIndex, newIndex)
    })
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCenter}
      onDragEnd={handleDragEnd}
    >
      <SortableContext
        items={items.map((i) => i.id)}
        strategy={verticalListSortingStrategy}
      >
        <div className="flex flex-col gap-2">
          {items.map((item) => (
            <SortableItem key={item.id} id={item.id} label={item.label} />
          ))}
        </div>
      </SortableContext>
    </DndContext>
  )
}
```

## Persisting Order to Database

After drag end, save the new order:
```typescript
function handleDragEnd(event: DragEndEvent) {
  const { active, over } = event
  if (!over || active.id === over.id) return

  const newItems = arrayMove(
    items,
    items.findIndex((i) => i.id === active.id),
    items.findIndex((i) => i.id === over.id)
  )
  setItems(newItems)

  // Save order to server
  const orderUpdate = newItems.map((item, index) => ({
    id: item.id,
    sort_order: index,
  }))

  fetch('/api/items/reorder', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ items: orderUpdate }),
  })
}
```

```sql
-- Database column for order
ALTER TABLE items ADD COLUMN sort_order INTEGER DEFAULT 0;

-- Update many rows at once
UPDATE items SET sort_order = data.sort_order
FROM (VALUES ('id1', 0), ('id2', 1), ('id3', 2)) AS data(id, sort_order)
WHERE items.id = data.id::uuid;
```

## Drag Overlay (Better UX)

Show a "ghost" preview while dragging instead of moving the actual element:
```typescript
import { DragOverlay } from '@dnd-kit/core'
import { useState } from 'react'

const [activeId, setActiveId] = useState<string | null>(null)

<DndContext
  onDragStart={({ active }) => setActiveId(active.id as string)}
  onDragEnd={(event) => {
    setActiveId(null)
    handleDragEnd(event)
  }}
>
  <SortableContext items={...}>
    {/* items */}
  </SortableContext>
  <DragOverlay>
    {activeId ? (
      <div className="shadow-xl opacity-90">
        <SortableItem id={activeId} label={getItemLabel(activeId)} />
      </div>
    ) : null}
  </DragOverlay>
</DndContext>
```

## File Drop Zone

For file uploads, use `react-dropzone`:
```bash
npm install react-dropzone
```

```typescript
import { useDropzone } from 'react-dropzone'

export function FileDropZone({ onFilesAccepted }: { onFilesAccepted: (files: File[]) => void }) {
  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    accept: { 'image/*': ['.png', '.jpg', '.jpeg', '.webp'] },
    maxSize: 5 * 1024 * 1024,  // 5MB
    onDrop: onFilesAccepted,
  })

  return (
    <div
      {...getRootProps()}
      className={`border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors ${
        isDragActive ? 'border-primary bg-primary/5' : 'border-muted-foreground/25 hover:border-primary/50'
      }`}
    >
      <input {...getInputProps()} />
      {isDragActive ? (
        <p>Drop files here...</p>
      ) : (
        <p className="text-muted-foreground">
          Drag & drop files here, or click to select
        </p>
      )}
    </div>
  )
}
```

## Kanban Board

For multi-column drag and drop (kanban), use `SortableContext` with `horizontalListSortingStrategy` for columns and `verticalListSortingStrategy` for cards, with nested `DndContext`. Cards can be dragged between columns by checking which container the `over` target belongs to.
