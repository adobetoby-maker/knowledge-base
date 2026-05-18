# Pattern: Drag-Reorder Sortable List

A list where users can reorder items via drag, keyboard arrow keys, and touch. Order is persisted to the server. Screen readers get live announcements.

## Why dnd-kit over react-beautiful-dnd

`react-beautiful-dnd` is unmaintained. `dnd-kit` is modular, actively maintained, supports touch natively, and has first-class keyboard support. The API is lower-level but more composable.

## Basic Setup

```tsx
import {
  DndContext, closestCenter, KeyboardSensor, PointerSensor,
  useSensor, useSensors, DragEndEvent,
} from '@dnd-kit/core';
import {
  SortableContext, sortableKeyboardCoordinates,
  useSortable, verticalListSortingStrategy, arrayMove,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';

function SortableList<T extends { id: string }>({
  items,
  onReorder,
  renderItem,
}: {
  items: T[];
  onReorder: (items: T[]) => void;
  renderItem: (item: T, handle: React.HTMLAttributes<HTMLElement>) => React.ReactNode;
}) {
  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (over && active.id !== over.id) {
      const oldIndex = items.findIndex(i => i.id === active.id);
      const newIndex = items.findIndex(i => i.id === over.id);
      onReorder(arrayMove(items, oldIndex, newIndex));
    }
  }

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
      <SortableContext items={items.map(i => i.id)} strategy={verticalListSortingStrategy}>
        {items.map(item => (
          <SortableItem key={item.id} id={item.id} renderItem={renderItem} item={item} />
        ))}
      </SortableContext>
    </DndContext>
  );
}
```

## Sortable Item with Drag Handle

Separate the drag handle from the item content. Full-item drag targets conflict with interactive children (buttons, inputs).

```tsx
function SortableItem<T extends { id: string }>({ id, item, renderItem }: {
  id: string;
  item: T;
  renderItem: (item: T, handle: React.HTMLAttributes<HTMLElement>) => React.ReactNode;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
    zIndex: isDragging ? 1 : 0,
  };

  const handleProps = { ...attributes, ...listeners };

  return (
    <div ref={setNodeRef} style={style}>
      {renderItem(item, handleProps)}
    </div>
  );
}
```

The `handleProps` are spread onto whatever element serves as the drag handle (a grip icon, for example). This keeps buttons and inputs in the row fully interactive.

## Keyboard Arrow-Key Reorder

`KeyboardSensor` with `sortableKeyboardCoordinates` handles this automatically. When an item is focused:
- `Space` or `Enter` — picks up the item
- `ArrowUp` / `ArrowDown` — moves it
- `Space` / `Enter` — drops it
- `Escape` — cancels

No extra code required. The sensor handles focus management and keyboard events.

## Touch Support

`PointerSensor` covers both mouse and touch. For touch-heavy interfaces, add a delay to disambiguate between taps and drags:

```tsx
const sensors = useSensors(
  useSensor(PointerSensor, {
    activationConstraint: {
      delay: 150,        // ms before drag activates (allows tap events through)
      tolerance: 5,      // px movement tolerance during delay
    },
  }),
  useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
);
```

Without the delay, tapping a button inside a draggable row may accidentally start a drag.

## Server Persistence

Persist order optimistically — update local state immediately, then sync to server.

```tsx
const [items, setItems] = useState(initialItems);
const [isSaving, setIsSaving] = useState(false);

const handleReorder = useCallback(async (newItems: Item[]) => {
  setItems(newItems); // optimistic update
  setIsSaving(true);
  try {
    await fetch('/api/items/reorder', {
      method: 'PATCH',
      body: JSON.stringify({ order: newItems.map((item, i) => ({ id: item.id, position: i })) }),
    });
  } catch {
    setItems(items); // revert on failure
    toast.error('Failed to save order');
  } finally {
    setIsSaving(false);
  }
}, [items]);
```

Store `position` as an integer column in the database. Fractional indexing (e.g., Lexorank) handles frequent reorders without full table updates but is only necessary at scale.

## Screen Reader Announcements

dnd-kit provides `DragOverlay` and `announcements` for accessible feedback:

```tsx
<DndContext
  sensors={sensors}
  collisionDetection={closestCenter}
  onDragEnd={handleDragEnd}
  accessibility={{
    announcements: {
      onDragStart({ active }) {
        return `Picked up item: ${getItemLabel(active.id)}. Use arrow keys to move.`;
      },
      onDragOver({ active, over }) {
        if (over) return `Moving ${getItemLabel(active.id)} over ${getItemLabel(over.id)}.`;
      },
      onDragEnd({ active, over }) {
        if (over) return `Dropped ${getItemLabel(active.id)} in position ${getPosition(over.id)}.`;
      },
      onDragCancel({ active }) {
        return `Reordering cancelled. ${getItemLabel(active.id)} returned to original position.`;
      },
    },
  }}
>
```

## Key Rules

- Use `PointerSensor` not `MouseSensor` — it covers touch automatically
- Add `activationConstraint.delay` for touch-heavy UIs to prevent accidental drags
- Spread drag handle props only onto the grip icon, not the full row, to preserve interactive children
- Persist optimistically: update state first, sync to server, revert on failure
- Provide `accessibility.announcements` with meaningful labels — screenreader users need to know what moved where
- Store position as an integer column; fractional indexing only needed at scale
