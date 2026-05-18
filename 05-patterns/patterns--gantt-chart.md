# Pattern: Gantt Chart

## Overview

A Gantt chart displays project tasks as horizontal bars across a timeline. The main challenge is the coordinate system: translating date ranges into pixel positions, handling zoom levels (day/week/month views), and drag-to-reschedule without a charting library that fights your data model.

## Data Model

```ts
interface Task {
  id: string
  name: string
  startDate: Date
  endDate: Date        // exclusive — endDate is the day after last day of work
  dependencies: string[]  // task IDs that must complete before this starts
  assigneeId?: string
  progress: number     // 0–100
}
```

The key invariant: `endDate` is exclusive. A 1-day task has `startDate = Monday, endDate = Tuesday`. This makes duration calculation trivial: `(endDate - startDate) / msPerDay`.

## Coordinate Math

```ts
// Convert date → pixel position given visible range
function dateToX(date: Date, viewStart: Date, dayWidth: number): number {
  const dayOffset = (date.getTime() - viewStart.getTime()) / (1000 * 60 * 60 * 24)
  return Math.round(dayOffset * dayWidth)
}

// Convert pixel → date (inverse, for drag-drop)
function xToDate(x: number, viewStart: Date, dayWidth: number): Date {
  const dayOffset = x / dayWidth
  return new Date(viewStart.getTime() + dayOffset * 24 * 60 * 60 * 1000)
}

// Snap to nearest day boundary
function snapToDay(date: Date): Date {
  const snapped = new Date(date)
  snapped.setHours(0, 0, 0, 0)
  return snapped
}
```

`dayWidth` is the number of pixels per calendar day. Day view: 40px/day. Week view: 8px/day. Month view: 2px/day.

## Rendering the Grid

```tsx
function GanttGrid({ viewStart, viewEnd, dayWidth, height }: GanttGridProps) {
  const days: Date[] = []
  const current = new Date(viewStart)
  while (current < viewEnd) {
    days.push(new Date(current))
    current.setDate(current.getDate() + 1)
  }

  return (
    <svg width={days.length * dayWidth} height={height}>
      {days.map((day, i) => (
        <g key={day.toISOString()}>
          {/* Weekend shading */}
          {(day.getDay() === 0 || day.getDay() === 6) && (
            <rect
              x={i * dayWidth}
              y={0}
              width={dayWidth}
              height={height}
              fill="rgba(0,0,0,0.04)"
            />
          )}
          {/* Day separator */}
          <line
            x1={i * dayWidth}
            y1={0}
            x2={i * dayWidth}
            y2={height}
            stroke="#e5e7eb"
            strokeWidth={1}
          />
        </g>
      ))}
      {/* Today line */}
      <line
        x1={dateToX(new Date(), viewStart, dayWidth)}
        y1={0}
        x2={dateToX(new Date(), viewStart, dayWidth)}
        y2={height}
        stroke="#3b82f6"
        strokeWidth={2}
        strokeDasharray="4 2"
      />
    </svg>
  )
}
```

## Task Bars

```tsx
const ROW_HEIGHT = 40
const BAR_HEIGHT = 24
const BAR_OFFSET = (ROW_HEIGHT - BAR_HEIGHT) / 2

function TaskBar({ task, index, viewStart, dayWidth, onDrag }: TaskBarProps) {
  const x = dateToX(task.startDate, viewStart, dayWidth)
  const width = dateToX(task.endDate, viewStart, dayWidth) - x
  const y = index * ROW_HEIGHT + BAR_OFFSET

  return (
    <g>
      <rect
        x={x}
        y={y}
        width={width}
        height={BAR_HEIGHT}
        rx={4}
        fill="#3b82f6"
        className="cursor-grab active:cursor-grabbing"
        onMouseDown={(e) => onDrag(e, task.id)}
      />
      {/* Progress fill */}
      <rect
        x={x}
        y={y}
        width={width * (task.progress / 100)}
        height={BAR_HEIGHT}
        rx={4}
        fill="#1d4ed8"
      />
      {/* Label */}
      {width > 60 && (
        <text x={x + 8} y={y + 16} fill="white" fontSize={12} className="select-none">
          {task.name}
        </text>
      )}
    </g>
  )
}
```

## Drag to Reschedule

```ts
function useDragReschedule(viewStart: Date, dayWidth: number, onUpdate: (id: string, start: Date, end: Date) => void) {
  const dragging = useRef<{ taskId: string; startX: number; originalStart: Date; originalEnd: Date } | null>(null)

  function onMouseDown(e: React.MouseEvent, taskId: string, task: Task) {
    dragging.current = {
      taskId,
      startX: e.clientX,
      originalStart: task.startDate,
      originalEnd: task.endDate,
    }
    window.addEventListener('mousemove', onMouseMove)
    window.addEventListener('mouseup', onMouseUp)
  }

  function onMouseMove(e: MouseEvent) {
    if (!dragging.current) return
    const deltaX = e.clientX - dragging.current.startX
    const deltaDays = Math.round(deltaX / dayWidth)
    const msPerDay = 24 * 60 * 60 * 1000

    const newStart = snapToDay(new Date(dragging.current.originalStart.getTime() + deltaDays * msPerDay))
    const newEnd = snapToDay(new Date(dragging.current.originalEnd.getTime() + deltaDays * msPerDay))
    onUpdate(dragging.current.taskId, newStart, newEnd)
  }

  function onMouseUp() {
    dragging.current = null
    window.removeEventListener('mousemove', onMouseMove)
    window.removeEventListener('mouseup', onMouseUp)
  }

  return { onMouseDown }
}
```

## Dependency Arrows

```tsx
function DependencyArrow({ from, to, tasks, viewStart, dayWidth }: ArrowProps) {
  const fromTask = tasks.find(t => t.id === from)!
  const toTask = tasks.find(t => t.id === to)!
  const fromIndex = tasks.indexOf(fromTask)
  const toIndex = tasks.indexOf(toTask)

  const x1 = dateToX(fromTask.endDate, viewStart, dayWidth)
  const y1 = fromIndex * ROW_HEIGHT + ROW_HEIGHT / 2
  const x2 = dateToX(toTask.startDate, viewStart, dayWidth)
  const y2 = toIndex * ROW_HEIGHT + ROW_HEIGHT / 2

  // Elbow path: right → down/up → right
  const midX = x1 + (x2 - x1) / 2
  const d = `M ${x1} ${y1} H ${midX} V ${y2} H ${x2}`

  return (
    <path
      d={d}
      stroke="#9ca3af"
      strokeWidth={1.5}
      fill="none"
      markerEnd="url(#arrow)"
    />
  )
}
```

## Key Rules

- Store dates as ISO strings in the DB; parse to Date objects at the component boundary — never mutate Date objects (use `new Date(existing.getTime())` for clones).
- `endDate` exclusive simplifies duration math: `days = (end - start) / msPerDay`.
- Snap drag deltas to full day boundaries using `Math.round`, not `Math.floor` — users expect the bar to "stick" to the nearest day.
- Dependency arrows break if tasks are reordered — store display order separately from dependency order; don't derive one from the other.
- For large datasets (100+ tasks), virtualize the row list with `react-virtual` — SVG can render all the bars since they clip naturally, but the left-side task name list must be virtualized.
