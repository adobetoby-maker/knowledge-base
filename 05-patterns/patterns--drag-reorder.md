# Pattern: Drag to Reorder List

## Overview

Drag-and-drop reordering for lists: todo items, playlist tracks, sidebar menu items, or any ordered collection. Uses `@dnd-kit/sortable` with optimistic UI and float-based persistence.

## Float Position Strategy

Store position as a `FLOAT` column, not an integer index. Inserting between two items is `(before + after) / 2` — no reindexing required. Reindex when the gap gets too small (< 0.001):

```sql
ALTER TABLE tasks ADD COLUMN position FLOAT NOT NULL DEFAULT 0;
CREATE INDEX ON tasks (position);
```

## Sortable List Component

```tsx
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
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
  arrayMove,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { useState, useCallback } from 'react'

interface Item {
  id: string
  title: string
  position: number
}

export function SortableList({
  initialItems,
  onReorder,
}: {
  initialItems: Item[]
  onReorder: (itemId: string, newPosition: number) => Promise<void>
}) {
  const [items, setItems] = useState(initialItems)

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: { distance: 5 },  // 5px movement before drag starts
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  )

  const handleDragEnd = useCallback(
    async (event: DragEndEvent) => {
      const { active, over } = event
      if (!over || active.id === over.id) return

      setItems((currentItems) => {
        const oldIndex = currentItems.findIndex((i) => i.id === active.id)
        const newIndex = currentItems.findIndex((i) => i.id === over.id)
        const reordered = arrayMove(currentItems, oldIndex, newIndex)

        // Calculate new float position
        const prev = reordered[newIndex - 1]?.position
        const next = reordered[newIndex + 1]?.position

        let newPosition: number
        if (!prev && !next) newPosition = 1000
        else if (!prev) newPosition = next! - 1000
        else if (!next) newPosition = prev + 1000
        else newPosition = (prev + next) / 2

        // Optimistic update
        reordered[newIndex] = { ...reordered[newIndex], position: newPosition }

        // Persist in background
        onReorder(active.id as string, newPosition).catch(() => {
          setItems(currentItems)  // Rollback on failure
        })

        return reordered
      })
    },
    [onReorder],
  )

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
      <SortableContext items={items.map((i) => i.id)} strategy={verticalListSortingStrategy}>
        <ul className="space-y-2">
          {items.map((item) => (
            <SortableItem key={item.id} item={item} />
          ))}
        </ul>
      </SortableContext>
    </DndContext>
  )
}
```

## Sortable Item

```tsx
function SortableItem({ item }: { item: Item }) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: item.id })

  return (
    <li
      ref={setNodeRef}
      style={{
        transform: CSS.Transform.toString(transform),
        transition,
      }}
      className={`flex items-center gap-3 p-3 bg-white border rounded-lg ${
        isDragging ? 'opacity-50 shadow-lg z-50' : 'hover:border-gray-300'
      }`}
    >
      {/* Drag handle — only this part activates dragging */}
      <button
        {...attributes}
        {...listeners}
        className="cursor-grab active:cursor-grabbing text-gray-400 hover:text-gray-600 touch-none"
        aria-label="Drag to reorder"
      >
        <GripVerticalIcon className="w-4 h-4" />
      </button>

      <span className="flex-1 text-sm">{item.title}</span>
    </li>
  )
}
```

## Server Action

```ts
'use server'
export async function reorderItem(itemId: string, newPosition: number) {
  const supabase = createServerActionClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  await supabase
    .from('tasks')
    .update({ position: newPosition })
    .eq('id', itemId)
    .eq('user_id', user.id)  // Security: can only reorder own items

  // Check if reindex needed
  const { data: items } = await supabase
    .from('tasks')
    .select('id, position')
    .eq('user_id', user.id)
    .order('position')

  if (items && needsReindex(items)) {
    await reindexPositions(user.id, items)
  }
}

function needsReindex(items: Array<{ position: number }>): boolean {
  for (let i = 1; i < items.length; i++) {
    if (items[i].position - items[i - 1].position < 0.001) return true
  }
  return false
}

async function reindexPositions(userId: string, items: Array<{ id: string }>) {
  const updates = items.map((item, i) => ({
    id: item.id,
    position: (i + 1) * 1000,
  }))
  await supabase.from('tasks').upsert(updates).eq('user_id', userId)
}
```

## Drag Overlay for Visual Feedback

```tsx
import { DragOverlay } from '@dnd-kit/core'

// Inside DndContext, track active item
const [activeId, setActiveId] = useState<string | null>(null)
const activeItem = items.find((i) => i.id === activeId)

<DndContext
  onDragStart={(e) => setActiveId(e.active.id as string)}
  onDragEnd={(e) => { handleDragEnd(e); setActiveId(null) }}
  onDragCancel={() => setActiveId(null)}
>
  {/* ... */}
  <DragOverlay>
    {activeItem && <DragOverlayItem item={activeItem} />}
  </DragOverlay>
</DndContext>
```

`DragOverlay` renders a floating preview that follows the cursor. The original item becomes transparent (`opacity-50`). This visual pattern is more polished than moving the actual item.
