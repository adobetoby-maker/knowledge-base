# Pattern: Resizable Table Columns

## Overview
Browser tables with `table-layout: auto` recalculate all column widths on every content change, making pointer-driven resize impossible to anchor. `table-layout: fixed` locks column widths to what you explicitly set, which is the prerequisite for any resize interaction. Without min-width enforcement, users can collapse columns to zero and lose content permanently.

## Table Layout Foundation

```css
/* table-layout: fixed is non-negotiable for resizable columns */
/* Without it, the browser recalculates widths on every DOM change */
.resizable-table {
  table-layout: fixed;
  width: 100%;
  border-collapse: collapse;
}

/* Column widths are set on <col> elements, not <th> */
/* This separates layout from content */
.resizable-table col {
  /* Default width — overridden by JS state */
}

/* Resize handle sits at the right edge of each header cell */
.col-resize-handle {
  position: absolute;
  right: 0;
  top: 0;
  bottom: 0;
  width: 6px;
  cursor: col-resize;
  background: transparent;
  /* Expand hit target without changing visual width */
  padding: 0 2px;
  box-sizing: content-box;
}

.col-resize-handle:hover,
.col-resize-handle--active {
  background: var(--accent-color);
}

/* Prevent text selection during drag */
.resizing {
  user-select: none;
  -webkit-user-select: none;
}
```

## Resize Logic with Pointer Events

```ts
// Use pointerId / setPointerCapture instead of document mousemove
// Pointer capture keeps the events coming even if the cursor leaves the element
// This prevents the "resize stops when cursor moves too fast" bug

const MIN_COLUMN_WIDTH = 60; // px — below this, content becomes unreadable

function useColumnResize(
  colWidths: number[],
  setColWidths: (widths: number[]) => void
) {
  function startResize(colIndex: number, e: React.PointerEvent<HTMLDivElement>) {
    e.preventDefault();
    const startX = e.clientX;
    const startWidth = colWidths[colIndex];
    const handle = e.currentTarget;

    // Pointer capture: events continue on this element even if pointer moves off
    handle.setPointerCapture(e.pointerId);
    document.body.classList.add('resizing');

    function onMove(moveEvent: PointerEvent) {
      const delta = moveEvent.clientX - startX;
      const newWidth = Math.max(MIN_COLUMN_WIDTH, startWidth + delta);
      setColWidths(prev => {
        const next = [...prev];
        next[colIndex] = newWidth;
        return next;
      });
    }

    function onUp() {
      handle.removeEventListener('pointermove', onMove);
      handle.removeEventListener('pointerup', onUp);
      document.body.classList.remove('resizing');
      // Persist after drag ends, not on every pointermove
      persistColumnWidths(colWidths);
    }

    handle.addEventListener('pointermove', onMove);
    handle.addEventListener('pointerup', onUp);
  }

  return { startResize };
}
```

## Table Rendering

```tsx
function ResizableTable({ columns, data }: Props) {
  const [colWidths, setColWidths] = usePersistedState(
    'table-col-widths',
    columns.map(c => c.defaultWidth ?? 150)
  );
  const { startResize } = useColumnResize(colWidths, setColWidths);

  return (
    <table className="resizable-table">
      {/* <colgroup> drives actual column widths with table-layout: fixed */}
      <colgroup>
        {colWidths.map((w, i) => <col key={i} style={{ width: w }} />)}
      </colgroup>
      <thead>
        <tr>
          {columns.map((col, i) => (
            <th key={col.key} style={{ position: 'relative' }}>
              {col.label}
              {/* Don't put the handle on the last column — nowhere to resize to */}
              {i < columns.length - 1 && (
                <div
                  className="col-resize-handle"
                  onPointerDown={e => startResize(i, e)}
                  // Prevent text selection on double-click
                  onDoubleClick={e => e.preventDefault()}
                />
              )}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {data.map(row => (
          <tr key={row.id}>
            {columns.map((col, i) => (
              <td key={col.key} style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {row[col.key]}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
```

## Persistence

```ts
// Persist widths to localStorage keyed by table ID
// Don't persist on every pointermove — write once on pointerup
function usePersistedState(key: string, initial: number[]) {
  const [state, setState] = useState<number[]>(() => {
    try {
      const stored = localStorage.getItem(key);
      return stored ? JSON.parse(stored) : initial;
    } catch {
      return initial;
    }
  });

  function setAndPersist(widths: number[]) {
    setState(widths);
    localStorage.setItem(key, JSON.stringify(widths));
  }

  return [state, setAndPersist] as const;
}
```

## Key Rules
- `table-layout: fixed` is required — without it, column widths are browser-controlled
- Use `setPointerCapture` on the handle — this prevents resize stopping when cursor moves fast
- Enforce a minimum column width (60px or your narrowest readable content)
- Add `user-select: none` to `<body>` during drag to prevent text selection artifacts
- Persist widths on `pointerup`, not on every `pointermove` — throttle persistence
- Set `overflow: hidden; text-overflow: ellipsis` on cells — content must not blow out the column
- Skip the resize handle on the last column — there's no adjacent column to balance against
