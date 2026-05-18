# Status Badge Pattern

## The Component

A status badge maps a status value to a visual indicator. Define the mapping outside the component:

```typescript
// components/StatusBadge.tsx
import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'

type InvoiceStatus = 'draft' | 'pending' | 'paid' | 'overdue' | 'cancelled'

// Defined OUTSIDE component — not recreated on every render:
const STATUS_CONFIG: Record<InvoiceStatus, {
  label: string
  className: string
}> = {
  draft: {
    label: 'Draft',
    className: 'bg-gray-100 text-gray-700 border-gray-200',
  },
  pending: {
    label: 'Pending',
    className: 'bg-yellow-100 text-yellow-700 border-yellow-200',
  },
  paid: {
    label: 'Paid',
    className: 'bg-green-100 text-green-700 border-green-200',
  },
  overdue: {
    label: 'Overdue',
    className: 'bg-red-100 text-red-700 border-red-200',
  },
  cancelled: {
    label: 'Cancelled',
    className: 'bg-gray-100 text-gray-500 border-gray-200',
  },
}

export function InvoiceStatusBadge({ status }: { status: InvoiceStatus }) {
  const config = STATUS_CONFIG[status] ?? STATUS_CONFIG.draft
  
  return (
    <Badge
      variant="outline"
      className={cn('font-medium', config.className)}
    >
      {config.label}
    </Badge>
  )
}
```

## With Status Icons

For more visual differentiation:

```typescript
import { Clock, CheckCircle, AlertCircle, XCircle, FileText } from 'lucide-react'

const STATUS_CONFIG: Record<InvoiceStatus, {
  label: string
  icon: LucideIcon
  className: string
}> = {
  draft: { label: 'Draft', icon: FileText, className: 'text-gray-500' },
  pending: { label: 'Pending', icon: Clock, className: 'text-yellow-600' },
  paid: { label: 'Paid', icon: CheckCircle, className: 'text-green-600' },
  overdue: { label: 'Overdue', icon: AlertCircle, className: 'text-red-600' },
  cancelled: { label: 'Cancelled', icon: XCircle, className: 'text-gray-400' },
}

export function InvoiceStatusBadge({ status }: { status: InvoiceStatus }) {
  const config = STATUS_CONFIG[status] ?? STATUS_CONFIG.draft
  const Icon = config.icon
  
  return (
    <span className={cn('flex items-center gap-1.5 text-sm font-medium', config.className)}>
      <Icon className="h-3.5 w-3.5" />
      {config.label}
    </span>
  )
}
```

## TypeScript: Exhaustive Status Handling

Add a compile-time check to catch missing status values:

```typescript
// Using a switch that TypeScript can check for exhaustiveness:
function getStatusLabel(status: InvoiceStatus): string {
  switch (status) {
    case 'draft': return 'Draft'
    case 'pending': return 'Pending'
    case 'paid': return 'Paid'
    case 'overdue': return 'Overdue'
    case 'cancelled': return 'Cancelled'
    default: {
      const _exhaustive: never = status  // TypeScript error if a case is missing
      return 'Unknown'
    }
  }
}
```

When you add a new status to the union type, TypeScript immediately flags the `never` line, forcing you to handle it everywhere.

## Dot Indicator (Minimal)

For table cells where space is tight:

```typescript
const STATUS_COLORS: Record<InvoiceStatus, string> = {
  draft: 'bg-gray-400',
  pending: 'bg-yellow-400',
  paid: 'bg-green-400',
  overdue: 'bg-red-400',
  cancelled: 'bg-gray-300',
}

export function StatusDot({ status }: { status: InvoiceStatus }) {
  return (
    <div className="flex items-center gap-2">
      <div className={cn('h-2 w-2 rounded-full', STATUS_COLORS[status])} />
      <span className="text-sm capitalize">{status}</span>
    </div>
  )
}
```

## Filtering by Status

Use the status values as filter options — pull from the config:

```typescript
const statusOptions = Object.entries(STATUS_CONFIG).map(([value, config]) => ({
  value,
  label: config.label,
}))

// In FilterBar:
<Select value={selectedStatus} onValueChange={setStatus}>
  <SelectContent>
    <SelectItem value="">All statuses</SelectItem>
    {statusOptions.map(opt => (
      <SelectItem key={opt.value} value={opt.value}>
        <div className="flex items-center gap-2">
          <StatusDot status={opt.value as InvoiceStatus} />
          {opt.label}
        </div>
      </SelectItem>
    ))}
  </SelectContent>
</Select>
```

Single source of truth: `STATUS_CONFIG` drives the badge display AND the filter options.
