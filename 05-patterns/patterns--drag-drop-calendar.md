# Pattern: Calendar with Drag-to-Reschedule

## Why This Pattern Matters

Dragging events on a calendar is intuitive but technically hard. The snap-to-grid, conflict detection, and undo behavior are where most implementations break. Get them wrong and users either can't place events precisely or accidentally create overlapping meetings with no way to recover.

## dnd-kit Setup

Use `useDraggable` on each calendar event, `useDroppable` on each time-slot cell.

```tsx
// Each time slot cell
function TimeSlot({ date, hour }: { date: Date; hour: number }) {
  const { setNodeRef, isOver } = useDroppable({
    id: `slot-${format(date, 'yyyy-MM-dd')}-${hour}`,
    data: { date, hour },
  });
  return (
    <div ref={setNodeRef} className={cn('h-14 border-b', isOver && 'bg-primary/10')} />
  );
}

// Each event
function CalendarEvent({ event }: { event: Event }) {
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({
    id: event.id,
    data: { event },
  });
  return (
    <div
      ref={setNodeRef}
      {...listeners}
      {...attributes}
      className={cn('absolute rounded p-1 text-xs', isDragging && 'opacity-50')}
    />
  );
}
```

## Snapping Events to Time Grid

Calculate the target slot from the drop position by reading `over.data.current` in the `onDragEnd` handler. The drop target provides `{ date, hour }` directly — no pixel math needed when slots are drop targets.

```ts
function onDragEnd({ active, over }: DragEndEvent) {
  if (!over) return;
  const { date, hour } = over.data.current as { date: Date; hour: number };
  const { event } = active.data.current as { event: Event };
  const newStart = setHours(date, hour);
  const duration = differenceInMinutes(event.end, event.start);
  const newEnd = addMinutes(newStart, duration);
  reschedule(event.id, newStart, newEnd);
}
```

For finer granularity (15-min slots), make each quarter-hour a separate drop target.

## DragOverlay for Ghost Element

Use `DragOverlay` to render a floating ghost that follows the cursor. This avoids layout shifts in the calendar grid during drag.

```tsx
<DragOverlay>
  {activeEvent && (
    <div className="rounded bg-primary text-primary-foreground p-1 text-xs shadow-lg opacity-90">
      {activeEvent.title}
    </div>
  )}
</DragOverlay>
```

## Conflict Detection

After computing the new time range, check for overlaps before committing:

```ts
function hasConflict(events: Event[], moved: Event, newStart: Date, newEnd: Date) {
  return events
    .filter(e => e.id !== moved.id)
    .some(e => newStart < e.end && newEnd > e.start);
}
```

On conflict: show an inline warning tooltip near the target slot while dragging (update a `conflictSlot` state in `onDragOver`). On drop into a conflict: present a confirmation dialog — "This overlaps with [Event Name]. Move anyway?" — not a silent failure.

## Undo Last Move

Keep a `lastMove` ref: `{ eventId, previousStart, previousEnd }`. On `onDragEnd`, set it before applying the change. Render a toast with an "Undo" action that restores the previous times.

```ts
const lastMove = useRef<{ id: string; start: Date; end: Date } | null>(null);

function reschedule(id: string, newStart: Date, newEnd: Date) {
  const event = getEvent(id);
  lastMove.current = { id, start: event.start, end: event.end };
  applyReschedule(id, newStart, newEnd);
  toast('Event moved', {
    action: { label: 'Undo', onClick: () => applyReschedule(id, lastMove.current!.start, lastMove.current!.end) },
  });
}
```

## Touch Support

dnd-kit supports touch natively via `TouchSensor`. Add a 200ms delay to distinguish tap from drag:

```ts
const sensors = useSensors(
  useSensor(MouseSensor, { activationConstraint: { distance: 5 } }),
  useSensor(TouchSensor, { activationConstraint: { delay: 200, tolerance: 5 } }),
);
```

## Key Rules

- Use `useDroppable` on time slots, not pixel math in `onDragOver`
- `DragOverlay` is mandatory — prevents grid layout thrash during drag
- Conflict detection runs in `onDragOver` (live feedback) and again on `onDragEnd` (gate)
- Undo is a toast action, not a separate button
- Touch activation delay 200ms to avoid false drags on scroll
- Preserve event duration when rescheduling — don't reset to default length
