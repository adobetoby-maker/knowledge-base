# Pattern: Status Transition Flow (State Machine UI)

## Overview
Record status (e.g., order: pending → processing → shipped → delivered) follows a state machine where only certain transitions are valid. Showing only allowed transitions (rather than all possible statuses) prevents invalid state changes without requiring backend validation errors to teach the user the rules. Requiring confirmation before irreversible transitions (like "Archive" or "Cancel") protects against accidental status changes on production data. An audit trail answers "who changed this and when" — essential for any multi-user workflow.

## Implementation

### State Machine Definition
```tsx
type OrderStatus = 'draft' | 'pending' | 'processing' | 'shipped' | 'delivered' | 'cancelled' | 'refunded'

interface Transition {
  to: OrderStatus
  label: string
  confirmRequired: boolean // true for irreversible
  confirmMessage?: string
  undoWindowMs?: number    // if set, show undo toast for this duration
}

const TRANSITIONS: Record<OrderStatus, Transition[]> = {
  draft: [
    { to: 'pending', label: 'Submit Order', confirmRequired: false },
  ],
  pending: [
    { to: 'processing', label: 'Start Processing', confirmRequired: false },
    {
      to: 'cancelled',
      label: 'Cancel Order',
      confirmRequired: true,
      confirmMessage: 'This will cancel the order and notify the customer.',
    },
  ],
  processing: [
    { to: 'shipped', label: 'Mark Shipped', confirmRequired: false, undoWindowMs: 10000 },
    { to: 'cancelled', label: 'Cancel', confirmRequired: true, confirmMessage: 'Cancel this order?' },
  ],
  shipped: [
    { to: 'delivered', label: 'Mark Delivered', confirmRequired: false },
    { to: 'refunded', label: 'Issue Refund', confirmRequired: true, confirmMessage: 'Refund and return to customer?' },
  ],
  delivered: [
    { to: 'refunded', label: 'Issue Refund', confirmRequired: true, confirmMessage: 'Issue a refund for this order?' },
  ],
  cancelled: [], // terminal — no further transitions
  refunded: [],  // terminal
}
```

### Transition Button Group
```tsx
function StatusTransitionButtons({
  currentStatus,
  onTransition,
}: {
  currentStatus: OrderStatus
  onTransition: (to: OrderStatus) => Promise<void>
}) {
  const [confirming, setConfirming] = useState<Transition | null>(null)
  const [loading, setLoading] = useState(false)

  const transitions = TRANSITIONS[currentStatus]

  const handleClick = (transition: Transition) => {
    if (transition.confirmRequired) {
      setConfirming(transition)
    } else {
      execute(transition)
    }
  }

  const execute = async (transition: Transition) => {
    setLoading(true)
    setConfirming(null)
    try {
      await onTransition(transition.to)
    } finally {
      setLoading(false)
    }
  }

  if (transitions.length === 0) {
    return <p className="text-sm text-gray-400">No further actions available.</p>
  }

  return (
    <>
      <div className="flex flex-wrap gap-2">
        {transitions.map((t) => (
          <button
            key={t.to}
            type="button"
            disabled={loading}
            onClick={() => handleClick(t)}
            className={[
              'px-4 py-2 rounded text-sm font-medium transition-colors',
              t.confirmRequired
                ? 'bg-red-50 border border-red-300 text-red-700 hover:bg-red-100'
                : 'bg-blue-600 text-white hover:bg-blue-700',
              'disabled:opacity-50',
            ].join(' ')}
          >
            {t.label}
          </button>
        ))}
      </div>

      {confirming && (
        <ConfirmDialog
          message={confirming.confirmMessage ?? `Move to ${confirming.to}?`}
          onConfirm={() => execute(confirming)}
          onCancel={() => setConfirming(null)}
        />
      )}
    </>
  )
}
```

### Status Badge
```tsx
const STATUS_BADGE_STYLES: Record<OrderStatus, string> = {
  draft: 'bg-gray-100 text-gray-600',
  pending: 'bg-yellow-100 text-yellow-700',
  processing: 'bg-blue-100 text-blue-700',
  shipped: 'bg-indigo-100 text-indigo-700',
  delivered: 'bg-green-100 text-green-700',
  cancelled: 'bg-red-100 text-red-700',
  refunded: 'bg-orange-100 text-orange-700',
}

function StatusBadge({ status }: { status: OrderStatus }) {
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${STATUS_BADGE_STYLES[status]}`}>
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  )
}
```

### Audit Trail
```tsx
interface AuditEntry {
  from: OrderStatus | null
  to: OrderStatus
  actor: string
  actorId: string
  timestamp: string
  note?: string
}

function AuditTrail({ entries }: { entries: AuditEntry[] }) {
  return (
    <ol className="relative border-l border-gray-200 ml-3 space-y-4">
      {entries.map((entry, i) => (
        <li key={i} className="pl-6">
          <div className="absolute -left-1.5 w-3 h-3 rounded-full bg-gray-300 border-2 border-white" />
          <p className="text-sm font-medium">
            {entry.from ? (
              <>
                <StatusBadge status={entry.from} />
                <span className="mx-1 text-gray-400">→</span>
              </>
            ) : null}
            <StatusBadge status={entry.to} />
          </p>
          <p className="text-xs text-gray-500 mt-0.5">
            by {entry.actor} · {formatRelativeTime(entry.timestamp)}
          </p>
          {entry.note && (
            <p className="text-xs text-gray-600 mt-1 italic">{entry.note}</p>
          )}
        </li>
      ))}
    </ol>
  )
}
```

### Undo Window (for non-irreversible transitions)
```tsx
function useUndoWindow(onUndo: () => void, windowMs: number) {
  const [active, setActive] = useState(false)
  const timerRef = useRef<ReturnType<typeof setTimeout>>()

  const start = () => {
    setActive(true)
    clearTimeout(timerRef.current)
    timerRef.current = setTimeout(() => setActive(false), windowMs)
  }

  const undo = () => {
    clearTimeout(timerRef.current)
    setActive(false)
    onUndo()
  }

  useEffect(() => () => clearTimeout(timerRef.current), [])

  return { active, start, undo }
}
```

## Key Rules
- Show only valid next transitions as buttons — hide forbidden ones entirely, don't show them disabled
- Irreversible transitions (cancel, archive, refund) require a confirmation dialog with a specific description of consequences
- Terminal states (cancelled, refunded) show no transition buttons — never show a disabled "No actions" button, show a text message instead
- Audit trail is append-only — never edit or delete past entries; this is the source of truth for disputes
- Status badge color must be consistent across the entire application — define it once in a config object
- Undo window (e.g., 10 seconds after "Mark Shipped") is appropriate for transitions that are reversible but costly to undo through the normal flow
- Never use `disabled` on forbidden transitions — hiding is clearer than a disabled button with no explanation
- Record the actor (user ID + name) and timestamp in every audit entry — "who changed it" is the most frequent audit query
