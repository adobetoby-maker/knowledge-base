# Pattern: Dense Data Grid

A high-density table with column resize, sort, filter, virtual scrolling for large datasets, column visibility persistence, CSV export, and row actions.

## Virtual Scrolling is Non-Negotiable for Large Datasets

Rendering 10,000 rows in the DOM is a 3–10 second render and ~500MB of memory. Virtual scrolling renders only the ~20–50 visible rows and recycles them as the user scrolls. Use `@tanstack/react-virtual` for row virtualization.

```tsx
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualGrid({ rows, columns }: { rows: Row[]; columns: Column[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const rowVirtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 36, // row height in px
    overscan: 5,            // extra rows above/below viewport for smooth scroll
  });

  return (
    <div ref={parentRef} className="h-[600px] overflow-auto">
      <div style={{ height: rowVirtualizer.getTotalSize() }} className="relative">
        {rowVirtualizer.getVirtualItems().map(virtualRow => (
          <div
            key={virtualRow.index}
            style={{
              position: 'absolute',
              top: virtualRow.start,
              height: virtualRow.size,
            }}
            className="flex w-full border-b hover:bg-muted/50"
          >
            {columns.map(col => (
              <Cell key={col.id} row={rows[virtualRow.index]} column={col} />
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
```

`estimateSize` should match the actual row height. Variable-height rows require `measureElement` which is more complex — prefer fixed-height rows in dense grids.

## Column State Management

Manage column state (widths, sort, visibility) in a single object that can be persisted to localStorage.

```tsx
type ColumnState = {
  width: number;
  visible: boolean;
  sortDirection: 'asc' | 'desc' | null;
};

type GridState = {
  columns: Record<string, ColumnState>;
};

const DEFAULT_COLUMN_WIDTH = 150;

function useGridState(columnDefs: ColumnDef[], storageKey: string) {
  const [state, setState] = useState<GridState>(() => {
    try {
      const stored = localStorage.getItem(storageKey);
      if (stored) return JSON.parse(stored);
    } catch {}
    return {
      columns: Object.fromEntries(
        columnDefs.map(col => [col.id, { width: col.defaultWidth ?? DEFAULT_COLUMN_WIDTH, visible: true, sortDirection: null }])
      ),
    };
  });

  const updateColumn = (id: string, patch: Partial<ColumnState>) => {
    setState(prev => {
      const next = { ...prev, columns: { ...prev.columns, [id]: { ...prev.columns[id], ...patch } } };
      localStorage.setItem(storageKey, JSON.stringify(next));
      return next;
    });
  };

  return { state, updateColumn };
}
```

## Column Resize

Track mouse position delta on mousedown and update the column width.

```tsx
function ResizeHandle({ columnId, onResize }: { columnId: string; onResize: (delta: number) => void }) {
  const startX = useRef<number>(0);

  const handleMouseDown = (e: React.MouseEvent) => {
    e.preventDefault();
    startX.current = e.clientX;

    const handleMouseMove = (e: MouseEvent) => {
      onResize(e.clientX - startX.current);
      startX.current = e.clientX;
    };
    const handleMouseUp = () => {
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };

    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
  };

  return (
    <div
      className="absolute right-0 top-0 h-full w-1 cursor-col-resize hover:bg-primary/50"
      onMouseDown={handleMouseDown}
    />
  );
}
```

Listen on `document`, not the element — mouse can move outside the handle during fast drags.

## CSV Export

```tsx
function exportToCsv(rows: Row[], columns: ColumnDef[], filename = 'export.csv') {
  const visibleCols = columns.filter(col => col.visible !== false);
  const header = visibleCols.map(col => `"${col.label}"`).join(',');
  const body = rows.map(row =>
    visibleCols.map(col => {
      const value = row[col.id] ?? '';
      const str = String(value).replace(/"/g, '""'); // escape quotes
      return `"${str}"`;
    }).join(',')
  ).join('\n');

  const blob = new Blob([header + '\n' + body], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
```

Always wrap values in quotes and escape internal quotes — unquoted values break on commas and newlines in data.

## Row Actions Menu

Use a dropdown that appears on row hover or a dedicated actions column at the end.

```tsx
function RowActionsMenu({ row, actions }: { row: Row; actions: RowAction[] }) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" className="h-6 w-6 opacity-0 group-hover:opacity-100">
          <MoreHorizontalIcon size={14} />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {actions.map(action => (
          <DropdownMenuItem key={action.id} onClick={() => action.handler(row)} className={cn(action.destructive && 'text-destructive')}>
            {action.label}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
```

## Key Rules

- Virtual scrolling is required above ~200 rows — rendering everything kills performance
- `estimateSize` must match actual row height; wrong estimates cause scroll jumpiness
- Listen for resize mousemove on `document`, not the handle element
- Column state belongs in localStorage so it survives page refresh — include a `storageKey` prop
- CSV values must be quoted and internal quotes escaped — data will contain commas
- Row actions should only appear on hover (`opacity-0 group-hover:opacity-100`) to reduce visual noise
