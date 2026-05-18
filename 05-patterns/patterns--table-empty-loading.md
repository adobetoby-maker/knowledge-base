# Pattern: Table with Loading / Empty / Data States

## Overview
A table component must handle three states cleanly: loading (skeleton rows), empty (empty state with CTA), and populated (real rows). The common failure is building these as three separate components or using ad-hoc conditionals scattered throughout the render — this leads to flashing (loading briefly shows empty before data arrives) and layout shift (skeleton rows have different height than real rows). The solution is a single component driven by an explicit `status` prop.

## Implementation

### Status-driven table component

```tsx
type TableStatus = 'loading' | 'empty' | 'data'

interface DataTableProps<T> {
  columns: ColumnDef<T>[]
  rows: T[]
  status: TableStatus
  emptyState?: {
    title: string
    description?: string
    action?: { label: string; onClick: () => void } | { label: string; href: string }
  }
  skeletonRowCount?: number
}

function DataTable<T extends { id: string }>({
  columns,
  rows,
  status,
  emptyState = { title: 'No results' },
  skeletonRowCount = 5,
}: DataTableProps<T>) {
  return (
    <div className="rounded-xl border overflow-hidden">
      <table className="w-full text-sm">
        <thead className="border-b bg-gray-50">
          <tr>
            {columns.map((col) => (
              <th key={col.key} className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-400">
                {col.header}
              </th>
            ))}
          </tr>
        </thead>

        <tbody className="divide-y">
          {status === 'loading' && (
            <>
              {Array.from({ length: skeletonRowCount }).map((_, i) => (
                <SkeletonRow key={i} columns={columns} />
              ))}
            </>
          )}

          {status === 'empty' && (
            <tr>
              <td colSpan={columns.length} className="py-16 px-4 text-center">
                <EmptyStateContent state={emptyState} />
              </td>
            </tr>
          )}

          {status === 'data' && rows.map((row) => (
            <DataRow key={row.id} row={row} columns={columns} />
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

### Skeleton row — same structure as data row

```tsx
function SkeletonRow<T>({ columns }: { columns: ColumnDef<T>[] }) {
  return (
    <tr aria-hidden="true">
      {columns.map((col) => (
        <td key={col.key} className="px-4 py-3">
          <div
            className="h-4 bg-gray-100 rounded animate-pulse"
            style={{ width: col.skeletonWidth ?? '70%' }}
          />
        </td>
      ))}
    </tr>
  )
}
```

### Data row

```tsx
function DataRow<T extends { id: string }>({
  row,
  columns,
}: {
  row: T
  columns: ColumnDef<T>[]
}) {
  return (
    <tr className="hover:bg-gray-50 transition-colors">
      {columns.map((col) => (
        <td key={col.key} className="px-4 py-3 text-gray-700">
          {col.render
            ? col.render(row[col.key as keyof T], row)
            : String(row[col.key as keyof T] ?? '—')}
        </td>
      ))}
    </tr>
  )
}
```

### Empty state

```tsx
function EmptyStateContent({ state }: { state: NonNullable<DataTableProps<never>['emptyState']> }) {
  return (
    <div className="flex flex-col items-center gap-3">
      <div className="w-12 h-12 rounded-full bg-gray-100 flex items-center justify-center">
        <InboxIcon size={24} className="text-gray-400" />
      </div>
      <div>
        <p className="font-medium text-gray-700">{state.title}</p>
        {state.description && <p className="text-sm text-gray-400 mt-0.5">{state.description}</p>}
      </div>
      {state.action && (
        'href' in state.action
          ? <Button variant="outline" size="sm" href={state.action.href}>{state.action.label}</Button>
          : <Button variant="outline" size="sm" onClick={state.action.onClick}>{state.action.label}</Button>
      )}
    </div>
  )
}
```

### Column definition with skeleton width

```ts
interface ColumnDef<T> {
  key: string
  header: string
  skeletonWidth?: string  // e.g. '60%', '80px' — controls skeleton placeholder width
  render?: (value: T[keyof T], row: T) => React.ReactNode
}

const userColumns: ColumnDef<User>[] = [
  { key: 'name',   header: 'Name',   skeletonWidth: '55%' },
  { key: 'email',  header: 'Email',  skeletonWidth: '80%' },
  { key: 'role',   header: 'Role',   skeletonWidth: '40%' },
  { key: 'status', header: 'Status', skeletonWidth: '30%', render: (v) => <StatusBadge status={v as string} /> },
]
```

### Usage with TanStack Query

```tsx
function UsersTable() {
  const { data, isLoading, isError } = useQuery({
    queryKey: ['users'],
    queryFn: fetchUsers,
  })

  // Derive status from query state
  const status: TableStatus = isLoading ? 'loading'
    : !data || data.length === 0 ? 'empty'
    : 'data'

  if (isError) return <ErrorState type="server-error" />

  return (
    <DataTable
      columns={userColumns}
      rows={data ?? []}
      status={status}
      emptyState={{
        title: 'No users yet',
        description: 'Invite your first team member to get started.',
        action: { label: 'Invite user', onClick: openInviteModal },
      }}
      skeletonRowCount={8}
    />
  )
}
```

## Key Rules
- Use an explicit `status` prop (`'loading' | 'empty' | 'data'`) — never derive visibility from `data?.length` directly in the render (leads to flash-of-empty during loading)
- Skeleton rows must have the same height as data rows — prevents layout shift on transition
- The table `<thead>` always renders — it shouldn't disappear when loading or empty
- Empty state lives inside a `<td colSpan={columns.length}>` — not outside the table (breaks table semantics)
- `skeletonWidth` per column approximates realistic content widths (name ~55%, email ~80%)
- Loading state never shows the empty state — the status enum prevents this by construction
- The CTA in the empty state should be the primary action to create the first item
- `aria-hidden="true"` on skeleton rows — they're presentational, not real content
