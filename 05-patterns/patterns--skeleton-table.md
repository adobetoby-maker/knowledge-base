# Skeleton Table — Loading State for Data Tables

## Match Row Count to Expected Data

The skeleton should have the same row count as what will load. If the table fetches 10 rows per page, show 10 skeleton rows. If the count is unknown (first load), use 5-8 rows — enough to communicate "a table is coming," not so many it dominates the viewport. After first load, store the last known page size in state and use that for subsequent skeleton renders.

```tsx
const FALLBACK_ROW_COUNT = 8

function TableSkeleton({ columns, rowCount = FALLBACK_ROW_COUNT }: Props) {
  return (
    <table>
      <tbody>
        {Array.from({ length: rowCount }, (_, row) => (
          <tr key={row}>
            {columns.map((col, ci) => (
              <td key={ci} style={{ width: col.width }}>
                <div className={cn("h-4 rounded bg-muted animate-pulse", getSkeletonWidth(col, row))} />
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  )
}
```

## Column Width Variation — Fake Natural Variance

Identical-width skeleton cells look artificial and draw attention to the fact that it's fake. Randomize widths per cell, but **seed the randomization by (row, column)** so it's stable across renders — no shimmer-width-jitter when the component re-renders.

```ts
// Deterministic "random" width — same output for same (row, col)
function getSkeletonWidth(col: Column, row: number): string {
  const seed = (row * 7 + col.index * 13) % 4
  const widths = ['w-3/4', 'w-2/3', 'w-4/5', 'w-1/2']
  return widths[seed]
}
```

Columns that always hold fixed-width data (checkboxes, action buttons, status badges) should have fixed skeleton widths, not randomized — e.g., a status column is always the same width.

## Shimmer Animation

Prefer `animate-pulse` (Tailwind built-in) over a custom shimmer for most cases. Use a shimmer gradient only when the product requires it:

```css
/* Custom shimmer if needed */
@keyframes shimmer {
  from { background-position: -200% 0; }
  to   { background-position:  200% 0; }
}
.shimmer {
  background: linear-gradient(90deg, hsl(var(--muted)) 25%, hsl(var(--muted-foreground) / 0.1) 50%, hsl(var(--muted)) 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite linear;
}
```

`animate-pulse` is simpler and less visually distracting for most table contexts. The shimmer gradient is better for image/card skeletons where the sweep communicates "loading in progress."

## No Layout Shift on Replace

The real table and skeleton table must have identical column widths. The skeleton column widths should be driven by the same column definition object as the real table:

```ts
const columns: ColumnDef[] = [
  { key: 'name', header: 'Name', width: '40%' },
  { key: 'status', header: 'Status', width: '120px' },
  { key: 'date', header: 'Date', width: '160px' },
]
// Pass same `columns` to both TableSkeleton and DataTable
```

Render the `<thead>` in the skeleton too (with real header text). This prevents the header row from shifting when data loads in.

## Accessibility

The skeleton table is decorative — mark it with `aria-hidden="true"` or `aria-busy="true"` on the container. Screen readers shouldn't read out 8 rows of "loading loading loading."

```tsx
<div aria-busy={isLoading} aria-label="Loading table data">
  {isLoading ? <TableSkeleton columns={columns} /> : <DataTable data={data} columns={columns} />}
</div>
```

## Key Rules

- Row count matches expected page size; fall back to 8 if unknown.
- Randomize skeleton cell widths deterministically by `(row, col)` seed — not truly random.
- Fixed-width columns (checkbox, badge, actions) use fixed skeleton widths.
- Include `<thead>` in the skeleton to prevent header layout shift on load.
- Mark skeleton with `aria-hidden` or container with `aria-busy` — don't expose to screen readers.
- Same column definition drives both skeleton and real table widths.
