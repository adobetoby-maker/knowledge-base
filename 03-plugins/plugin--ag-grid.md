# Plugin: AG Grid (Community Edition)

## Purpose
Render large, interactive data tables with sorting, filtering, inline editing, and virtual scrolling. AG Grid Community is free and sufficient for most use cases. AG Grid Enterprise adds features like row grouping, pivoting, and Excel export — evaluate whether you need them before committing to the license.

## Column Definitions

`columnDefs` defines columns explicitly; `defaultColDef` sets defaults applied to every column. Set shared behavior in `defaultColDef` and override per column in `columnDefs`:

```tsx
const defaultColDef = {
  sortable: true,
  filter: true,
  resizable: true,
  flex: 1,          // distribute available width
};

const columnDefs = [
  { field: 'name', headerName: 'Customer', minWidth: 150 },
  { field: 'amount', headerName: 'Amount', type: 'numericColumn', valueFormatter: p => `$${p.value}` },
  { field: 'status', editable: true, cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: ['active', 'inactive'] } },
];
```

Avoid duplicating properties that belong in `defaultColDef` — they're hard to maintain across many columns.

## Row Data Update Patterns
Two strategies for updating grid data — pick based on volume:

**Full replace** (small datasets, <10k rows): set a new `rowData` prop. Simple, predictable, triggers a full re-render. Fine for most cases.

**Delta update** (large datasets, frequent updates): use `getRowId` + `applyTransactionAsync`:
```tsx
// Required for delta updates — tells AG Grid how to identify a row
const getRowId = useCallback((params) => String(params.data.id), []);

// Later, when data changes:
gridRef.current.api.applyTransactionAsync({
  add: newRows,
  update: changedRows,
  remove: deletedRows,
});
```
Delta updates are dramatically faster for live data — they only re-render changed rows. Without `getRowId`, delta updates fall back to full re-renders, eliminating the benefit.

## Inline Editing with `onCellValueChanged`
```tsx
const onCellValueChanged = useCallback(async (event: CellValueChangedEvent) => {
  const { data, colDef, newValue, oldValue } = event;
  if (newValue === oldValue) return;
  try {
    await updateRecord(data.id, { [colDef.field!]: newValue });
  } catch {
    // Revert: set the old value back
    event.node.setDataValue(colDef.field!, oldValue);
  }
}, []);
```
Always handle the failure case by reverting the cell value. The grid is optimistic by default — if the API call fails, the UI shows the new value while the DB has the old one. Revert explicitly.

## Row Identity with `getRowId`
Always define `getRowId` when you will update rows after initial load. Without it, AG Grid uses array index as identity — any row insertion or deletion shifts indices and causes wrong rows to update. The ID must be a stable string:

```tsx
getRowId={(params) => String(params.data.id)}
```

## Virtual Scrolling Behavior
AG Grid virtualizes rows by default — only visible rows are in the DOM. This means:
- `document.querySelectorAll('.ag-row')` will not find all rows — iterate `api.forEachNode()` instead
- Row heights must be consistent unless you enable `dynamicRowHeight` (performance cost)
- Printing requires `api.setDomLayout('print')` to de-virtualize before `window.print()`

## Common Gotchas
- `rowData` must be a stable reference when using delta updates — recreating the array on every render defeats the purpose
- `columnDefs` updates that replace the array cause column animations/reflows — memoize with `useMemo`
- Cell renderers must be memoized — they render once per visible cell, so they fire frequently
- `suppressRowClickSelection` defaults to false — clicking a row selects it, which may surprise users who expect click-to-edit

## Key Rules
- **Always set `getRowId`** when rows will update after initial load
- **Use `defaultColDef` for shared behavior** — don't repeat `sortable: true` on every column
- **Revert cell value on failed save** — the grid is optimistic, your API is not
- **Iterate via `api.forEachNode()`** — don't query the DOM for rows that may not be rendered
- **Memoize `columnDefs` with `useMemo`** — array recreation triggers unnecessary column reflows
- **Delta updates require `getRowId`** — without it they fall back to full re-renders
