# Skill: Time Tracking

## Overview

Track time spent on tasks, projects, or clients. Core objects: `time_entries` (start/end timestamps), `projects`, and optionally `clients`. Key behaviors: active timer (start without end), manual entry (both start and end), and reporting by date range. Store all times in UTC; convert to user's timezone for display only.

## Schema

```sql
CREATE TABLE projects (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     UUID NOT NULL REFERENCES organizations(id),
  name       TEXT NOT NULL,
  color      TEXT NOT NULL DEFAULT '#3b82f6',
  archived   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE time_entries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id),
  project_id  UUID REFERENCES projects(id),
  description TEXT NOT NULL DEFAULT '',
  started_at  TIMESTAMPTZ NOT NULL,
  ended_at    TIMESTAMPTZ,                  -- NULL = timer is running
  duration_seconds INT,                     -- Computed on stop; NULL while running
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Only one active timer per user at a time
CREATE UNIQUE INDEX one_active_timer ON time_entries(user_id)
  WHERE ended_at IS NULL;

CREATE INDEX time_entries_user_date ON time_entries(user_id, started_at DESC);
CREATE INDEX time_entries_project ON time_entries(project_id, started_at DESC);
```

## Start/Stop Timer

```ts
export async function startTimer(userId: string, projectId: string | null, description: string) {
  // Stop any running timer first
  await stopActiveTimer(userId)

  return db.insert(timeEntries).values({
    userId,
    projectId,
    description,
    startedAt: new Date(),
  }).returning()
}

export async function stopActiveTimer(userId: string): Promise<void> {
  const active = await db.query.timeEntries.findFirst({
    where: and(eq(timeEntries.userId, userId), isNull(timeEntries.endedAt)),
  })

  if (!active) return

  const now = new Date()
  const durationSeconds = Math.round((now.getTime() - active.startedAt.getTime()) / 1000)

  await db.update(timeEntries)
    .set({ endedAt: now, durationSeconds })
    .where(eq(timeEntries.id, active.id))
}
```

## Live Timer Display

```tsx
function LiveTimer({ startedAt }: { startedAt: Date }) {
  const [elapsed, setElapsed] = useState(0)

  useEffect(() => {
    const initial = Math.floor((Date.now() - startedAt.getTime()) / 1000)
    setElapsed(initial)

    const id = setInterval(() => {
      setElapsed(s => s + 1)
    }, 1000)

    return () => clearInterval(id)
  }, [startedAt])

  return <span className="font-mono tabular-nums">{formatDuration(elapsed)}</span>
}

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}
```

## Time Entry List with Daily Grouping

```ts
async function getTimeEntriesGroupedByDay(userId: string, from: Date, to: Date) {
  const entries = await db.query.timeEntries.findMany({
    where: and(
      eq(timeEntries.userId, userId),
      gte(timeEntries.startedAt, from),
      lte(timeEntries.startedAt, to),
      isNotNull(timeEntries.endedAt),  // Completed entries only
    ),
    orderBy: [desc(timeEntries.startedAt)],
    with: { project: true },
  })

  // Group by local date (user timezone)
  const grouped = new Map<string, typeof entries>()
  for (const entry of entries) {
    // Format date in user's timezone
    const date = entry.startedAt.toLocaleDateString('en-CA', { timeZone: getUserTimezone() })
    const group = grouped.get(date) ?? []
    group.push(entry)
    grouped.set(date, group)
  }

  return grouped
}
```

## Daily/Weekly Summary

```ts
async function getTimeSummary(userId: string, from: Date, to: Date) {
  const result = await db.execute(sql`
    SELECT
      project_id,
      p.name as project_name,
      p.color as project_color,
      SUM(duration_seconds) as total_seconds,
      COUNT(*) as entry_count
    FROM time_entries te
    LEFT JOIN projects p ON te.project_id = p.id
    WHERE te.user_id = ${userId}
      AND te.started_at >= ${from}
      AND te.started_at < ${to}
      AND te.ended_at IS NOT NULL
    GROUP BY project_id, p.name, p.color
    ORDER BY total_seconds DESC
  `)

  return result.map(row => ({
    projectId: row.project_id,
    projectName: row.project_name ?? 'No project',
    projectColor: row.project_color ?? '#6b7280',
    totalSeconds: Number(row.total_seconds),
    totalFormatted: formatDuration(Number(row.total_seconds)),
    entryCount: Number(row.entry_count),
  }))
}
```

## Key Rules

- The unique partial index (`WHERE ended_at IS NULL`) enforces one active timer per user at the DB level — not just application logic.
- Store `duration_seconds` on stop rather than computing it every time in queries — makes aggregates fast.
- Always work in UTC for storage; apply timezone conversion only at display time using `Intl.DateTimeFormat` or `date-fns-tz`.
- `started_at` alone is sufficient to detect a running timer (`ended_at IS NULL`) — no need for a separate `is_running` column.
- When editing a completed entry, recalculate `duration_seconds` from `ended_at - started_at`.
