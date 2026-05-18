# Pattern: Kanban Board

## Overview

Full kanban board: columns (statuses), cards, drag-to-reorder within column, drag-to-move between columns. Uses `@dnd-kit` (see `plugin--dnd-kit.md` for drag primitives). This pattern covers the complete board assembly.

## Data Model

```ts
interface KanbanCard {
  id: string
  title: string
  description?: string
  columnId: string
  position: number  // Sort order within column
  assigneeId?: string
  dueDate?: string
  priority?: 'low' | 'medium' | 'high'
}

interface KanbanColumn {
  id: string
  title: string
  color: string
  cards: KanbanCard[]
}
```

## Database Schema

```sql
CREATE TABLE kanban_columns (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES auth.users(id),
  title      TEXT NOT NULL,
  color      TEXT NOT NULL DEFAULT '#6b7280',
  position   INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE kanban_cards (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  column_id   UUID NOT NULL REFERENCES kanban_columns(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  title       TEXT NOT NULL,
  description TEXT,
  position    FLOAT NOT NULL,  -- Float allows inserting between items without reindexing
  due_date    DATE,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_kanban_cards_column ON kanban_cards(column_id, position);
```

`FLOAT` position uses the "gap strategy" — insert between 1.0 and 2.0 by calculating `(1.0 + 2.0) / 2 = 1.5`. Only reindex when gap < 0.001.

## Board Component

```tsx
'use client'
import { useState, useCallback } from 'react'
import {
  DndContext, DragOverlay, PointerSensor,
  useSensor, useSensors, DragEndEvent, DragOverEvent,
  closestCorners
} from '@dnd-kit/core'
import { SortableContext, verticalListSortingStrategy } from '@dnd-kit/sortable'

interface KanbanBoardProps {
  initialColumns: KanbanColumn[]
  onMoveCard: (cardId: string, toColumnId: string, position: number) => Promise<void>
  onReorderCard: (cardId: string, position: number) => Promise<void>
}

export function KanbanBoard({ initialColumns, onMoveCard, onReorderCard }: KanbanBoardProps) {
  const [columns, setColumns] = useState(initialColumns)
  const [activeCard, setActiveCard] = useState<KanbanCard | null>(null)

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: { distance: 5 },  // 5px before drag starts
    })
  )

  const handleDragEnd = useCallback(async (event: DragEndEvent) => {
    const { active, over } = event
    if (!over) return

    const cardId = active.id as string
    const overId = over.id as string

    // Find source and destination
    let sourceCol = columns.find(col => col.cards.some(c => c.id === cardId))
    let destCol = columns.find(col => col.id === overId || col.cards.some(c => c.id === overId))

    if (!sourceCol || !destCol) return

    if (sourceCol.id === destCol.id) {
      // Reorder within column
      const cards = [...sourceCol.cards]
      const fromIdx = cards.findIndex(c => c.id === cardId)
      const toIdx = cards.findIndex(c => c.id === overId)

      if (fromIdx === toIdx) return

      // Calculate new position
      const before = toIdx > 0 ? cards[toIdx - 1].position : 0
      const after = toIdx < cards.length - 1 ? cards[toIdx + 1].position : cards[toIdx].position + 1
      const newPosition = (before + after) / 2

      // Optimistic update
      const [removed] = cards.splice(fromIdx, 1)
      removed.position = newPosition
      cards.splice(toIdx, 0, removed)
      setColumns(cols => cols.map(col =>
        col.id === sourceCol!.id ? { ...col, cards } : col
      ))

      await onReorderCard(cardId, newPosition)
    } else {
      // Move to different column
      const destCards = [...destCol.cards]
      const overIdx = destCards.findIndex(c => c.id === overId)
      const insertIdx = overIdx >= 0 ? overIdx : destCards.length

      const before = insertIdx > 0 ? destCards[insertIdx - 1].position : 0
      const after = insertIdx < destCards.length ? destCards[insertIdx].position : (before + 1)
      const newPosition = (before + after) / 2

      // Optimistic update
      const card = sourceCol.cards.find(c => c.id === cardId)!
      card.position = newPosition
      card.columnId = destCol.id

      setColumns(cols => cols.map(col => {
        if (col.id === sourceCol!.id) return { ...col, cards: col.cards.filter(c => c.id !== cardId) }
        if (col.id === destCol!.id) {
          const updated = [...col.cards, card].sort((a, b) => a.position - b.position)
          return { ...col, cards: updated }
        }
        return col
      }))

      await onMoveCard(cardId, destCol.id, newPosition)
    }

    setActiveCard(null)
  }, [columns, onMoveCard, onReorderCard])

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragStart={({ active }) => {
        const card = columns.flatMap(c => c.cards).find(c => c.id === active.id)
        setActiveCard(card ?? null)
      }}
      onDragEnd={handleDragEnd}
    >
      <div className="flex gap-4 overflow-x-auto pb-4">
        {columns.map((column) => (
          <KanbanColumn key={column.id} column={column} />
        ))}
      </div>

      <DragOverlay>
        {activeCard && <KanbanCardDragOverlay card={activeCard} />}
      </DragOverlay>
    </DndContext>
  )
}
```

## Column Component

```tsx
import { useDroppable } from '@dnd-kit/core'
import { SortableContext, verticalListSortingStrategy } from '@dnd-kit/sortable'

function KanbanColumn({ column }: { column: KanbanColumn }) {
  const { setNodeRef } = useDroppable({ id: column.id })

  return (
    <div className="flex-none w-64">
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full" style={{ backgroundColor: column.color }} />
          <h3 className="font-medium text-sm">{column.title}</h3>
          <span className="text-xs text-gray-500 bg-gray-100 px-1.5 rounded-full">
            {column.cards.length}
          </span>
        </div>
        <button className="text-gray-400 hover:text-gray-600">+</button>
      </div>

      <div
        ref={setNodeRef}
        className="space-y-2 min-h-[100px] bg-gray-50 rounded-lg p-2"
      >
        <SortableContext
          items={column.cards.map(c => c.id)}
          strategy={verticalListSortingStrategy}
        >
          {column.cards.map((card) => (
            <SortableCard key={card.id} card={card} />
          ))}
        </SortableContext>
      </div>
    </div>
  )
}
```

## Sortable Card

```tsx
import { useSortable } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'

function SortableCard({ card }: { card: KanbanCard }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: card.id,
  })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  }

  return (
    <div
      ref={setNodeRef}
      style={style}
      {...attributes}
      {...listeners}
      className="bg-white rounded-lg p-3 shadow-sm border cursor-grab active:cursor-grabbing"
    >
      <p className="text-sm font-medium">{card.title}</p>
      {card.description && (
        <p className="text-xs text-gray-500 mt-1 truncate">{card.description}</p>
      )}
      {card.dueDate && (
        <div className="flex items-center gap-1 mt-2 text-xs text-gray-400">
          📅 {card.dueDate}
        </div>
      )}
    </div>
  )
}
```

## Position Reindexing

When float position gap becomes too small (`< 0.001`), reindex:

```ts
async function reindexColumnPositions(columnId: string) {
  const { data: cards } = await supabase
    .from('kanban_cards')
    .select('id')
    .eq('column_id', columnId)
    .order('position')

  if (!cards) return

  const updates = cards.map((card, i) => ({
    id: card.id,
    position: (i + 1) * 1000,  // 1000, 2000, 3000 — plenty of room
  }))

  await supabase.from('kanban_cards').upsert(updates)
}
```
