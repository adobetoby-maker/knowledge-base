# Pattern: Responsive Data Table

## Overview
Data tables built for desktop break on smaller screens because tables don't reflow naturally. The solution is a three-tier approach: full table on desktop, hide non-essential columns on tablet, switch to a card-per-row layout on mobile. The column visibility configuration should live in the table definition (not scattered in CSS) so it's maintainable as the table evolves.

## Implementation

### Column definition with visibility priority

```ts
interface ColumnDef<T> {
  key: keyof T
  header: string
  priority: 'always' | 'tablet' | 'desktop'  // 'always' = shown at all sizes
  render?: (value: T[keyof T], row: T) => React.ReactNode
  className?: string
}

const userColumns: ColumnDef<User>[] = [
  { key: 'name',      header: 'Name',        priority: 'always' },
  { key: 'email',     header: 'Email',       priority: 'tablet' },
  { key: 'role',      header: 'Role',        priority: 'tablet' },
  { key: 'status',    header: 'Status',      priority: 'always' },
  { key: 'createdAt', header: 'Joined',      priority: 'desktop' },
  { key: 'lastLogin', header: 'Last Login',  priority: 'desktop' },
  { key: 'actions',   header: '',            priority: 'always' },
]
```

### Responsive table component

```tsx
function ResponsiveTable<T extends { id: string }>({
  columns,
  data,
}: {
  columns: ColumnDef<T>[]
  data: T[]
}) {
  const [viewMode, setViewMode] = useState<'table' | 'cards'>('table')

  // Switch to card view on small screens
  useEffect(() => {
    const mq = window.matchMedia('(max-width: 639px)')
    const handler = (e: MediaQueryListEvent) => setViewMode(e.matches ? 'cards' : 'table')
    setViewMode(mq.matches ? 'cards' : 'table')
    mq.addEventListener('change', handler)
    return () => mq.removeEventListener('change', handler)
  }, [])

  if (viewMode === 'cards') {
    return <CardView columns={columns} data={data} />
  }

  return <TableView columns={columns} data={data} />
}
```

### Desktop/tablet table view

```tsx
function TableView<T extends { id: string }>({ columns, data }: { columns: ColumnDef<T>[]; data: T[] }) {
  return (
    // overflow-x-auto is the safety net for tablet sizes between breakpoints
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b text-left text-xs uppercase tracking-wider text-gray-400">
            {columns.map((col) => (
              <th
                key={String(col.key)}
                className={[
                  'py-3 px-4',
                  col.priority === 'desktop' ? 'hidden lg:table-cell' : '',
                  col.priority === 'tablet'  ? 'hidden sm:table-cell' : '',
                ].join(' ')}
              >
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.map((row) => (
            <tr key={row.id} className="border-b hover:bg-gray-50">
              {columns.map((col) => (
                <td
                  key={String(col.key)}
                  className={[
                    'py-3 px-4',
                    col.priority === 'desktop' ? 'hidden lg:table-cell' : '',
                    col.priority === 'tablet'  ? 'hidden sm:table-cell' : '',
                    col.className ?? '',
                  ].join(' ')}
                >
                  {col.render
                    ? col.render(row[col.key], row)
                    : String(row[col.key] ?? '—')}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

### Mobile card view

```tsx
function CardView<T extends { id: string }>({ columns, data }: { columns: ColumnDef<T>[]; data: T[] }) {
  const [expandedId, setExpandedId] = useState<string | null>(null)

  // "Always" fields shown by default, others revealed on expand
  const primaryCols = columns.filter(c => c.priority === 'always')
  const secondaryCols = columns.filter(c => c.priority !== 'always')

  return (
    <div className="divide-y">
      {data.map((row) => {
        const isExpanded = expandedId === row.id
        return (
          <div key={row.id} className="py-3 px-4">
            {/* Primary fields always visible */}
            <div className="flex items-center justify-between">
              {primaryCols.slice(0, -1).map((col) => (
                <div key={String(col.key)}>
                  {col.render ? col.render(row[col.key], row) : String(row[col.key] ?? '')}
                </div>
              ))}
              {/* Actions column (last 'always' col) */}
              {primaryCols.at(-1) && (
                <div>
                  {primaryCols.at(-1)!.render?.(row[primaryCols.at(-1)!.key], row)}
                </div>
              )}
            </div>

            {/* Secondary fields on expand */}
            {isExpanded && (
              <div className="mt-2 grid grid-cols-2 gap-2 text-sm text-gray-600">
                {secondaryCols.map((col) => (
                  <div key={String(col.key)}>
                    <span className="text-xs text-gray-400 block">{col.header}</span>
                    {col.render ? col.render(row[col.key], row) : String(row[col.key] ?? '—')}
                  </div>
                ))}
              </div>
            )}

            {secondaryCols.length > 0 && (
              <button
                className="text-xs text-blue-500 mt-1"
                onClick={() => setExpandedId(isExpanded ? null : row.id)}
              >
                {isExpanded ? 'Less' : 'More'}
              </button>
            )}
          </div>
        )
      })}
    </div>
  )
}
```

## Key Rules
- Column priority (`always` / `tablet` / `desktop`) belongs in the column definition — not in CSS classes scattered across the codebase
- `overflow-x: auto` on the table wrapper is the fallback for intermediate breakpoints
- Mobile card view should show the most important fields by default — don't hide the primary identifier
- Actions (edit, delete) are always `priority: 'always'` — never hidden
- Test the breakpoint transitions — there's often a range between sm/md where neither layout looks right
- Consider a "column chooser" toggle for power users on tablet (they can opt into more columns)
- Sort should work in both views — sort state is independent of display mode
