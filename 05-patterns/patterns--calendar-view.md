# Pattern: Calendar View

## Overview

Month-view calendar showing events/appointments on dates. Custom implementation — no library required for basic needs. For complex drag-and-drop scheduling, use `@fullcalendar/react`.

## Data Structure

```ts
interface CalendarEvent {
  id: string
  title: string
  date: string       // ISO date: "2026-01-15"
  color?: string     // "blue" | "red" | "green"
  href?: string      // Optional link
}

interface CalendarDay {
  date: Date
  events: CalendarEvent[]
  isCurrentMonth: boolean
  isToday: boolean
}
```

## Building the Calendar Grid

```ts
import {
  startOfMonth, endOfMonth, startOfWeek, endOfWeek,
  eachDayOfInterval, isSameMonth, isToday, format,
  addMonths, subMonths
} from 'date-fns'

function buildCalendarGrid(currentMonth: Date, events: CalendarEvent[]): CalendarDay[][] {
  const monthStart = startOfMonth(currentMonth)
  const monthEnd = endOfMonth(currentMonth)
  const gridStart = startOfWeek(monthStart)  // Sunday of first week
  const gridEnd = endOfWeek(monthEnd)        // Saturday of last week

  const days = eachDayOfInterval({ start: gridStart, end: gridEnd })

  // Map events by date string for O(1) lookup
  const eventsByDate = new Map<string, CalendarEvent[]>()
  for (const event of events) {
    const key = event.date
    if (!eventsByDate.has(key)) eventsByDate.set(key, [])
    eventsByDate.get(key)!.push(event)
  }

  const calendarDays: CalendarDay[] = days.map((date) => ({
    date,
    events: eventsByDate.get(format(date, 'yyyy-MM-dd')) ?? [],
    isCurrentMonth: isSameMonth(date, currentMonth),
    isToday: isToday(date),
  }))

  // Split into weeks
  const weeks: CalendarDay[][] = []
  for (let i = 0; i < calendarDays.length; i += 7) {
    weeks.push(calendarDays.slice(i, i + 7))
  }
  return weeks
}
```

## Calendar Component

```tsx
'use client'
import { useState } from 'react'
import { addMonths, subMonths, format } from 'date-fns'

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

const EVENT_COLORS: Record<string, string> = {
  blue: 'bg-blue-100 text-blue-800',
  red: 'bg-red-100 text-red-800',
  green: 'bg-green-100 text-green-800',
  default: 'bg-gray-100 text-gray-800',
}

interface CalendarProps {
  events: CalendarEvent[]
  onDateClick?: (date: Date) => void
  onEventClick?: (event: CalendarEvent) => void
}

export function Calendar({ events, onDateClick, onEventClick }: CalendarProps) {
  const [currentMonth, setCurrentMonth] = useState(new Date())
  const weeks = buildCalendarGrid(currentMonth, events)

  return (
    <div className="rounded-xl border bg-white overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b">
        <button
          onClick={() => setCurrentMonth(subMonths(currentMonth, 1))}
          className="p-2 hover:bg-gray-100 rounded-lg"
          aria-label="Previous month"
        >
          ←
        </button>
        <h2 className="text-lg font-semibold">
          {format(currentMonth, 'MMMM yyyy')}
        </h2>
        <button
          onClick={() => setCurrentMonth(addMonths(currentMonth, 1))}
          className="p-2 hover:bg-gray-100 rounded-lg"
          aria-label="Next month"
        >
          →
        </button>
      </div>

      {/* Weekday headers */}
      <div className="grid grid-cols-7 border-b">
        {WEEKDAYS.map((day) => (
          <div key={day} className="py-2 text-center text-xs font-medium text-gray-500">
            {day}
          </div>
        ))}
      </div>

      {/* Grid */}
      <div>
        {weeks.map((week, wi) => (
          <div key={wi} className="grid grid-cols-7 border-b last:border-b-0">
            {week.map((day) => (
              <div
                key={day.date.toISOString()}
                onClick={() => onDateClick?.(day.date)}
                className={`
                  min-h-[80px] p-1 border-r last:border-r-0 cursor-pointer
                  hover:bg-gray-50 transition-colors
                  ${!day.isCurrentMonth ? 'bg-gray-50' : ''}
                `}
              >
                {/* Day number */}
                <span
                  className={`
                    text-sm font-medium w-7 h-7 flex items-center justify-center rounded-full
                    ${day.isToday ? 'bg-blue-600 text-white' : ''}
                    ${!day.isCurrentMonth ? 'text-gray-400' : 'text-gray-900'}
                  `}
                >
                  {format(day.date, 'd')}
                </span>

                {/* Events */}
                <div className="mt-1 space-y-0.5">
                  {day.events.slice(0, 3).map((event) => (
                    <button
                      key={event.id}
                      onClick={(e) => { e.stopPropagation(); onEventClick?.(event) }}
                      className={`
                        w-full text-left text-xs px-1 py-0.5 rounded truncate
                        ${EVENT_COLORS[event.color ?? 'default']}
                      `}
                    >
                      {event.title}
                    </button>
                  ))}
                  {day.events.length > 3 && (
                    <div className="text-xs text-gray-500 px-1">
                      +{day.events.length - 3} more
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  )
}
```

## Fetching Events for Month

```ts
// Fetch events for the visible range (including prev/next month overflow)
async function fetchCalendarEvents(year: number, month: number) {
  const start = format(startOfWeek(startOfMonth(new Date(year, month - 1))), 'yyyy-MM-dd')
  const end = format(endOfWeek(endOfMonth(new Date(year, month - 1))), 'yyyy-MM-dd')

  const { data } = await supabase
    .from('appointments')
    .select('id, title, scheduled_date, type')
    .gte('scheduled_date', start)
    .lte('scheduled_date', end)

  return data ?? []
}
```

Query the full grid range (including overflow days from adjacent months) — users expect to see those events too.

## URL State for Month Navigation

```ts
// Keep month in URL so sharing/refreshing preserves view
'?month=2026-01'

const searchParams = useSearchParams()
const month = searchParams.get('month')
const currentMonth = month ? parseISO(`${month}-01`) : new Date()
```

## Accessibility

- Day cells: use `role="gridcell"` on each day
- Month navigation: `aria-label="Previous month"` / `aria-label="Next month"`  
- Event buttons: `aria-label={event.title}` + date
- Grid: `role="grid"` on the outer container, `role="row"` on week rows
