# Pattern: Bulk Status Update

## Overview
Bulk operations save users from repetitive work, but they introduce three hard problems: concurrent modification (another user changes one of the selected items before the bulk action executes), partial failure (some items succeed, some fail), and reversibility (can the user undo?). The UI must communicate the outcome of each item, keep failed items selected for retry, and process large batches server-side without timing out.

## Implementation

### Selection State
```tsx
function useSelection<T extends { id: string }>(items: T[]) {
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const toggle = (id: string) =>
    setSelected(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });

  const selectAll = () => setSelected(new Set(items.map(i => i.id)));
  const clearAll = () => setSelected(new Set());

  return { selected, toggle, selectAll, clearAll };
}
```

### Allowed Status Transitions
Restrict the status dropdown to valid transitions from the current statuses of selected items. If selected items have mixed statuses, show the intersection of valid transitions.

```ts
const STATUS_TRANSITIONS: Record<string, string[]> = {
  draft:    ['active', 'archived'],
  active:   ['paused', 'archived'],
  paused:   ['active', 'archived'],
  archived: [],
};

function getAllowedTransitions(statuses: string[]): string[] {
  if (statuses.length === 0) return [];
  const sets = statuses.map(s => STATUS_TRANSITIONS[s] ?? []);
  return sets.reduce((a, b) => a.filter(s => b.includes(s)));
}
```

### Confirmation Dialog
```tsx
function BulkStatusConfirm({
  count,
  targetStatus,
  onConfirm,
  onCancel,
}: {
  count: number;
  targetStatus: string;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <dialog open aria-modal="true">
      <p>
        Update <strong>{count.toLocaleString()} item{count !== 1 ? 's' : ''}</strong> to{' '}
        <strong>{targetStatus}</strong>?
      </p>
      <button onClick={onConfirm} autoFocus>Confirm</button>
      <button onClick={onCancel}>Cancel</button>
    </dialog>
  );
}
```

### Server-Side Batch Processing
```ts
// POST /api/items/bulk-status
async function POST(req: Request) {
  const { ids, targetStatus } = await req.json();
  if (!ids?.length || ids.length > 500) {
    return Response.json({ error: 'ids must be 1-500' }, { status: 400 });
  }

  const results: { id: string; success: boolean; error?: string }[] = [];

  // Process in chunks of 100 to avoid DB timeout
  for (const chunk of chunkArray(ids, 100)) {
    const chunkResults = await Promise.allSettled(
      chunk.map(id => updateItemStatus(id, targetStatus, session.userId))
    );
    chunkResults.forEach((r, i) => {
      results.push({
        id: chunk[i],
        success: r.status === 'fulfilled',
        error: r.status === 'rejected' ? r.reason?.message : undefined,
      });
    });
  }

  return Response.json({ results });
}
```

### Progress Toast + Failed Items Handling
```tsx
async function executeBulkUpdate(selectedIds: string[], targetStatus: string) {
  const ids = Array.from(selectedIds);
  showToast({ message: `Updating ${ids.length} items...`, duration: null });

  const res = await fetch('/api/items/bulk-status', {
    method: 'POST',
    body: JSON.stringify({ ids, targetStatus }),
    headers: { 'Content-Type': 'application/json' },
  });
  const { results } = await res.json();

  const failed = results.filter(r => !r.success);
  const succeeded = results.filter(r => r.success);

  dismissToast();

  if (failed.length === 0) {
    showToast({ message: `${succeeded.length} items updated to ${targetStatus}`, variant: 'success' });
    clearAll();
  } else {
    showToast({
      message: `${succeeded.length} updated, ${failed.length} failed`,
      variant: 'warning',
      duration: null,
    });
    // Keep only failed items selected so user can see what needs attention
    setSelected(new Set(failed.map(r => r.id)));
  }

  refetchItems();
}
```

## Key Rules
- Show the exact count in the confirmation dialog — "Update 12 items to Active?" not "Update selected items".
- Process server-side in chunks of 50–100 — single SQL UPDATE with an `IN` clause works for < 1000 rows, but `allSettled` per-item gives better partial-failure granularity.
- Failed items must stay selected after a partial failure — the user needs to see which items failed and retry.
- Clear selection after full success — don't leave stale checkmarks on already-updated items.
- Maximum selection limit (e.g., 500) prevents runaway operations — show a warning if user tries to select more.
- Show a progress indicator for batches over ~50 items — a silent wait of several seconds looks broken.
- Log every bulk operation in the audit trail: actor, target ids, old status, new status, timestamp.
