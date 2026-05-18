# Pattern: Drag to Reorder List

## Overview
Naive drag-and-drop implementations that save on every drag event hammer the API with hundreds of requests per second. Using the entire list item as the drag target makes long items with interactive elements (buttons, links) accidentally trigger drags. A visual placeholder at the drop position prevents disorientation — without it, users can't tell where the item will land.

## Implementation

```tsx
// ReorderableList.tsx
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragOverlay,
  type DragEndEvent,
  type DragStartEvent,
} from '@dnd-kit/core'
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  verticalListSortingStrategy,
  useSortable,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { useCallback, useRef, useState } from 'react'

interface Item {
  id: string
  title: string
  [key: string]: unknown
}

interface ReorderableListProps {
  items: Item[]
  onReorder: (items: Item[]) => Promise<void>
}

export function ReorderableList({ items: initialItems, onReorder }: ReorderableListProps) {
  const [items, setItems] = useState(initialItems)
  const [activeId, setActiveId] = useState<string | null>(null)
  const saveTimeoutRef = useRef<ReturnType<typeof setTimeout>>()

  const sensors = useSensors(
    useSensor(PointerSensor, {
      // Require 5px movement before drag starts — prevents accidental drags on click
      activationConstraint: { distance: 5 },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  )

  function handleDragStart(event: DragStartEvent) {
    setActiveId(String(event.active.id))
  }

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    setActiveId(null)

    if (!over || active.id === over.id) return

    setItems(prev => {
      const oldIndex = prev.findIndex(i => i.id === active.id)
      const newIndex = prev.findIndex(i => i.id === over.id)
      const reordered = arrayMove(prev, oldIndex, newIndex)

      // Debounce persistence: don't save on every drag frame
      // Only persist when user stops dragging
      clearTimeout(saveTimeoutRef.current)
      saveTimeoutRef.current = setTimeout(() => {
        onReorder(reordered).catch(err => {
          console.error('Failed to save order:', err)
          // Roll back to original order on failure
          setItems(prev)
        })
      }, 300)

      return reordered
    })
  }

  const activeItem = items.find(i => i.id === activeId)

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCenter}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
    >
      <SortableContext items={items} strategy={verticalListSortingStrategy}>
        <ul style={{ listStyle: 'none', padding: 0 }}>
          {items.map(item => (
            <SortableItem key={item.id} item={item} />
          ))}
        </ul>
      </SortableContext>

      {/* DragOverlay renders the dragged item at the cursor position */}
      {/* Without this, the original item disappears with no visual feedback */}
      <DragOverlay>
        {activeItem && (
          <div style={{ opacity: 0.85, boxShadow: '0 8px 16px rgba(0,0,0,0.15)' }}>
            <ItemCard item={activeItem} isDragging />
          </div>
        )}
      </DragOverlay>
    </DndContext>
  )
}
```

```tsx
// SortableItem.tsx — item with handle-only drag target
function SortableItem({ item }: { item: Item }) {
  const {
    attributes,
    listeners,
    setNodeRef,
    setActivatorNodeRef,  // The handle node
    transform,
    transition,
    isDragging,
  } = useSortable({ id: item.id })

  const style: React.CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition,
    // Placeholder effect: the original becomes ghosted when dragging
    opacity: isDragging ? 0.4 : 1,
  }

  return (
    <li ref={setNodeRef} style={style}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>

        {/* Drag HANDLE — only this triggers the drag, not the whole item */}
        {/* This prevents accidental drags when clicking buttons inside the item */}
        <button
          ref={setActivatorNodeRef}
          {...attributes}
          {...listeners}
          aria-label="Drag to reorder"
          style={{
            cursor: isDragging ? 'grabbing' : 'grab',
            background: 'none',
            border: 'none',
            padding: '4px',
            touchAction: 'none',  // Required for touch drag support
            color: '#999',
          }}
        >
          ⠿ {/* Drag handle icon */}
        </button>

        {/* Item content — buttons here won't trigger drag */}
        <ItemCard item={item} />
      </div>
    </li>
  )
}
```

```typescript
// Server-side persistence endpoint
// app/api/items/reorder/route.ts
export async function PUT(req: Request) {
  const { ids } = await req.json() as { ids: string[] }
  const user = await getUser(req)

  // Save the order as position integers, not as a JSON array
  // Integers are easier to query and update partially
  await db.transaction(async tx => {
    for (let i = 0; i < ids.length; i++) {
      await tx
        .update(items)
        .set({ position: i })
        .where(and(eq(items.id, ids[i]), eq(items.userId, user.id)))
    }
  })

  return Response.json({ ok: true })
}
```

## Key Rules
- Use dnd-kit (`@dnd-kit/core` + `@dnd-kit/sortable`) — it's accessible, touch-friendly, and the current standard.
- Use a dedicated drag handle element, not the full item — full-item drag targets conflict with click events on buttons inside.
- Set `activationConstraint: { distance: 5 }` to prevent accidental drags on click or tap.
- Debounce the persistence call (300ms after drag ends) — never save on every drag frame.
- Roll back UI state if the API call fails — don't leave the user with an unsaved order they think was saved.
- Use `DragOverlay` to show the dragged item at the cursor — without it there's no visual feedback of what's being dragged.
- The original item should become a ghost/placeholder (opacity 0.4) when dragging, so users see where it came from.
- Store order as integer position fields in the DB — easier to query sorted than parsing JSON arrays.
- Set `touchAction: none` on the drag handle for touch device support.
