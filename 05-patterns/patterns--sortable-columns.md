# Pattern: Sortable Table Columns

## Overview
Sortable columns without URL persistence break on page reload and prevent sharing filtered views. Without proper ARIA attributes, screen readers can't communicate sort state. The decision between client-side and server-side sorting determines architecture — get it wrong and large datasets feel slow.

## Implementation

```tsx
// types
type SortDirection = 'asc' | 'desc'
interface SortState {
  column: string
  direction: SortDirection
}

// useSortState.ts — syncs sort to URL query params
import { useRouter, useSearchParams } from 'next/navigation'
import { useCallback } from 'react'

export function useSortState(defaultColumn: string, defaultDir: SortDirection = 'desc') {
  const router = useRouter()
  const params = useSearchParams()

  const column = params.get('sort') ?? defaultColumn
  const direction = (params.get('dir') as SortDirection) ?? defaultDir

  const setSort = useCallback((col: string) => {
    const newDir: SortDirection =
      col === column && direction === 'asc' ? 'desc' : 'asc'

    const newParams = new URLSearchParams(params.toString())
    newParams.set('sort', col)
    newParams.set('dir', newDir)

    // Replace, not push — sorting isn't a navigation step users want to back through
    router.replace(`?${newParams.toString()}`, { scroll: false })
  }, [column, direction, params, router])

  return { column, direction, setSort }
}
```

```tsx
// SortableHeader.tsx
interface SortableHeaderProps {
  label: string
  columnKey: string
  currentSort: SortState
  onSort: (col: string) => void
}

export function SortableHeader({ label, columnKey, currentSort, onSort }: SortableHeaderProps) {
  const isActive = currentSort.column === columnKey
  const ariaSort = isActive
    ? currentSort.direction === 'asc' ? 'ascending' : 'descending'
    : 'none'

  return (
    <th
      aria-sort={ariaSort}   // Required for screen readers
      style={{ cursor: 'pointer', userSelect: 'none' }}
    >
      <button
        onClick={() => onSort(columnKey)}
        style={{
          background: 'none',
          border: 'none',
          padding: 0,
          cursor: 'inherit',
          display: 'flex',
          alignItems: 'center',
          gap: 4,
          fontWeight: isActive ? 700 : 400,
        }}
      >
        {label}
        {/* Visual chevron indicator */}
        <span aria-hidden style={{ opacity: isActive ? 1 : 0.3 }}>
          {!isActive && '↕'}
          {isActive && currentSort.direction === 'asc' && '↑'}
          {isActive && currentSort.direction === 'desc' && '↓'}
        </span>
      </button>
    </th>
  )
}
```

```tsx
// Table.tsx — wiring it together
export function UserTable({ users }: { users: User[] }) {
  const { column, direction, setSort } = useSortState('createdAt', 'desc')

  // CLIENT-SIDE SORT: use only when data is fully loaded in memory
  // For > 1000 rows or paginated data: sort server-side via URL params
  const sorted = [...users].sort((a, b) => {
    const aVal = a[column as keyof User]
    const bVal = b[column as keyof User]
    if (aVal == null) return 1
    if (bVal == null) return -1
    const cmp = aVal < bVal ? -1 : aVal > bVal ? 1 : 0
    return direction === 'asc' ? cmp : -cmp
  })

  const sortState = { column, direction }

  return (
    <table>
      <thead>
        <tr>
          <SortableHeader label="Name"    columnKey="name"      currentSort={sortState} onSort={setSort} />
          <SortableHeader label="Email"   columnKey="email"     currentSort={sortState} onSort={setSort} />
          <SortableHeader label="Joined"  columnKey="createdAt" currentSort={sortState} onSort={setSort} />
          <SortableHeader label="Status"  columnKey="status"    currentSort={sortState} onSort={setSort} />
        </tr>
      </thead>
      <tbody>
        {sorted.map(user => (
          <tr key={user.id}>
            <td>{user.name}</td>
            <td>{user.email}</td>
            <td>{formatDate(user.createdAt)}</td>
            <td>{user.status}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}
```

```tsx
// Server-side sort example (for paginated / large datasets)
// app/users/page.tsx — sort params passed to DB query
export default async function UsersPage({ searchParams }) {
  const sort = searchParams.sort ?? 'createdAt'
  const dir = searchParams.dir === 'asc' ? 'asc' : 'desc'

  const users = await db.user.findMany({
    orderBy: { [sort]: dir },
    take: 50,
    skip: (page - 1) * 50,
  })

  return <UserTable users={users} />
}
```

## Key Rules
- Persist sort state in the URL (`?sort=name&dir=asc`) — page reload and link sharing must preserve it.
- Use `router.replace` (not `push`) for sort changes — they are not navigation history users want to back through.
- Always set `aria-sort` on `<th>` elements: `"ascending"`, `"descending"`, or `"none"`.
- Clicking an already-active column header reverses direction; clicking a new column defaults to ascending.
- Default sort should reflect UX needs — newest-first (`createdAt desc`) is almost always right for lists.
- Client-side sort: only when all data is in memory. If the table is paginated, sort server-side.
- Server-side sort: read params in the data-fetching layer and pass to the DB `ORDER BY` clause.
- Show an inactive indicator (↕, low opacity) on sortable columns so users know they're clickable.
- Never sort strings with `>` / `<` for case-insensitive needs — use `localeCompare`.
