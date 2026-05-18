# Plugin: TanStack Table (react-table v8)

## Overview
TanStack Table is headless — it provides zero UI, only logic. You own 100% of the markup and styles. This is by design: the same table instance logic works in React, Solid, Vue, or Svelte. The tradeoff is more setup code up front, but you never fight the library's opinions about DOM structure. For large datasets (10k+ rows), combine with TanStack Virtual.

## Implementation

### Basic Table
```tsx
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  flexRender,
  type ColumnDef,
  type SortingState,
} from '@tanstack/react-table';

type Person = { id: string; name: string; age: number; email: string };

const columns: ColumnDef<Person>[] = [
  {
    accessorKey: 'name',       // dot-notation path into row data
    header: 'Name',
    cell: (info) => info.getValue(),
  },
  {
    accessorFn: (row) => row.age, // function for derived values
    id: 'age',
    header: () => <span>Age</span>,
  },
  {
    accessorKey: 'email',
    header: 'Email',
    enableSorting: false,
  },
];

export function DataTable({ data }: { data: Person[] }) {
  const [sorting, setSorting] = useState<SortingState>([]);
  const [globalFilter, setGlobalFilter] = useState('');

  const table = useReactTable({
    data,
    columns,
    state: { sorting, globalFilter },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    initialState: { pagination: { pageSize: 20 } },
  });

  return (
    <>
      <input value={globalFilter} onChange={e => setGlobalFilter(e.target.value)} placeholder="Search..." />
      <table>
        <thead>
          {table.getHeaderGroups().map(headerGroup => (
            <tr key={headerGroup.id}>
              {headerGroup.headers.map(header => (
                <th
                  key={header.id}
                  onClick={header.column.getToggleSortingHandler()}
                  style={{ cursor: header.column.getCanSort() ? 'pointer' : 'default' }}
                >
                  {flexRender(header.column.columnDef.header, header.getContext())}
                  {{ asc: ' ↑', desc: ' ↓' }[header.column.getIsSorted() as string] ?? null}
                </th>
              ))}
            </tr>
          ))}
        </thead>
        <tbody>
          {table.getRowModel().rows.map(row => (
            <tr key={row.id}>
              {row.getVisibleCells().map(cell => (
                <td key={cell.id}>
                  {flexRender(cell.column.columnDef.cell, cell.getContext())}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
      <div>
        <button onClick={() => table.previousPage()} disabled={!table.getCanPreviousPage()}>←</button>
        <span>Page {table.getState().pagination.pageIndex + 1} of {table.getPageCount()}</span>
        <button onClick={() => table.nextPage()} disabled={!table.getCanNextPage()}>→</button>
      </div>
    </>
  );
}
```

### Server-Side Pagination/Sorting
```tsx
// For large datasets: manualPagination + manualSorting
const table = useReactTable({
  data,
  columns,
  state: { sorting, pagination },
  onSortingChange: setSorting,
  onPaginationChange: setPagination,
  getCoreRowModel: getCoreRowModel(),
  manualPagination: true,   // tell table not to paginate data itself
  manualSorting: true,       // tell table not to sort data itself
  rowCount: totalRows,       // needed for page count calculation
});

// Use sorting/pagination state to drive your API call
useEffect(() => {
  fetchData({ sorting, pagination });
}, [sorting, pagination]);
```

### Virtual Rows (Large Datasets)
```tsx
import { useVirtualizer } from '@tanstack/react-virtual';

const parentRef = useRef<HTMLDivElement>(null);
const rows = table.getRowModel().rows;

const virtualizer = useVirtualizer({
  count: rows.length,
  getScrollElement: () => parentRef.current,
  estimateSize: () => 40, // row height in px
  overscan: 10,
});

// Render only virtualItems, offset the container
<div ref={parentRef} style={{ height: '600px', overflow: 'auto' }}>
  <div style={{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }}>
    {virtualizer.getVirtualItems().map(virtualRow => {
      const row = rows[virtualRow.index];
      return (
        <tr key={row.id} style={{ position: 'absolute', top: virtualRow.start, width: '100%' }}>
          {row.getVisibleCells().map(cell => (
            <td key={cell.id}>{flexRender(cell.column.columnDef.cell, cell.getContext())}</td>
          ))}
        </tr>
      );
    })}
  </div>
</div>
```

## Key Rules
- Always include at least `getCoreRowModel()` — without it the table renders nothing
- Add only the row model functions you need — each has a cost; unused ones should be omitted
- `accessorKey` for simple property paths; `accessorFn` + `id` for computed/transformed values
- `flexRender` is required for header and cell rendering — raw column defs are not React elements
- For server-side data: set `manualPagination: true` and `manualSorting: true` plus `rowCount`
- `table.getRowModel().rows` gives the processed rows (sorted, filtered, paginated); `table.getCoreRowModel().rows` gives raw rows
- Column visibility, row selection, and column pinning are all supported — check docs before building custom
- Memoize `columns` array (useMemo) to prevent table recreation on every parent render
