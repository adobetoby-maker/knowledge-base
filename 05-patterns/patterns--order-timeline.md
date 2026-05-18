# Pattern: Order Timeline

## Overview

Visual timeline showing order status progression: Placed → Confirmed → Shipped → Delivered. Also used for project milestones, application status, approval workflows. Key: mark completed steps clearly, highlight the current step, and show estimated dates for future steps.

## Schema

```sql
CREATE TABLE order_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     UUID NOT NULL REFERENCES orders(id),
  status       TEXT NOT NULL,     -- 'placed', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'
  note         TEXT,              -- "Shipped via FedEx #123456789"
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX order_events_order_id ON order_events(order_id, created_at ASC);
```

## Order Status Steps

```ts
interface OrderStep {
  id: string
  label: string
  description: string
  estimatedDate?: Date
  completedAt?: Date
  status: 'completed' | 'current' | 'upcoming' | 'cancelled'
}

function buildOrderTimeline(order: Order, events: OrderEvent[]): OrderStep[] {
  const STEPS = ['placed', 'confirmed', 'processing', 'shipped', 'delivered']

  const eventMap = new Map(events.map(e => [e.status, e.createdAt]))
  const currentIndex = STEPS.indexOf(order.status)

  return STEPS.map((step, i) => {
    const completedAt = eventMap.get(step)

    return {
      id: step,
      label: formatStepLabel(step),
      description: getStepDescription(step, order),
      completedAt,
      estimatedDate: !completedAt ? getEstimatedDate(step, order) : undefined,
      status: order.status === 'cancelled' && !completedAt
        ? 'cancelled'
        : completedAt
        ? 'completed'
        : i === currentIndex
        ? 'current'
        : 'upcoming',
    }
  })
}

function formatStepLabel(step: string): string {
  const labels: Record<string, string> = {
    placed: 'Order placed',
    confirmed: 'Order confirmed',
    processing: 'Being prepared',
    shipped: 'Shipped',
    delivered: 'Delivered',
  }
  return labels[step] ?? step
}
```

## Timeline Component

```tsx
interface TimelineProps {
  steps: OrderStep[]
}

export function OrderTimeline({ steps }: TimelineProps) {
  return (
    <ol className="relative">
      {steps.map((step, index) => (
        <li key={step.id} className="relative pl-8 pb-8 last:pb-0">
          {/* Connector line */}
          {index < steps.length - 1 && (
            <div
              className={cn(
                'absolute left-3 top-5 w-px',
                step.status === 'completed' ? 'bg-green-500' : 'bg-gray-200',
                'h-full'
              )}
            />
          )}

          {/* Step dot */}
          <div
            className={cn(
              'absolute left-0 top-1 w-6 h-6 rounded-full flex items-center justify-center',
              step.status === 'completed' && 'bg-green-500 text-white',
              step.status === 'current' && 'bg-blue-500 text-white ring-4 ring-blue-100',
              step.status === 'upcoming' && 'bg-gray-200 text-gray-400',
              step.status === 'cancelled' && 'bg-gray-100 text-gray-300',
            )}
          >
            {step.status === 'completed' ? (
              <CheckIcon className="w-3 h-3" />
            ) : step.status === 'current' ? (
              <div className="w-2 h-2 rounded-full bg-white" />
            ) : (
              <div className="w-2 h-2 rounded-full bg-current" />
            )}
          </div>

          {/* Content */}
          <div className="ml-2">
            <p
              className={cn(
                'font-medium text-sm',
                step.status === 'completed' && 'text-gray-900',
                step.status === 'current' && 'text-blue-700',
                step.status === 'upcoming' && 'text-gray-400',
                step.status === 'cancelled' && 'text-gray-300 line-through',
              )}
            >
              {step.label}
            </p>

            {step.description && (
              <p className="text-xs text-gray-500 mt-0.5">{step.description}</p>
            )}

            <p className="text-xs text-gray-400 mt-0.5">
              {step.completedAt ? (
                format(step.completedAt, 'MMM d, h:mm a')
              ) : step.estimatedDate ? (
                `Estimated: ${format(step.estimatedDate, 'MMM d')}`
              ) : null}
            </p>
          </div>
        </li>
      ))}
    </ol>
  )
}
```

## Cancellation Handling

```tsx
// When order is cancelled, show where it stopped
function buildCancelledTimeline(order: Order, events: OrderEvent[]): OrderStep[] {
  const steps = buildOrderTimeline(order, events)
  const cancelledStep: OrderStep = {
    id: 'cancelled',
    label: 'Cancelled',
    description: order.cancelReason ?? 'Order was cancelled',
    completedAt: order.cancelledAt ?? undefined,
    status: 'current',
  }

  // Insert after the last completed step
  const lastCompletedIndex = steps.findLastIndex(s => s.status === 'completed')
  steps.splice(lastCompletedIndex + 1, 0, cancelledStep)

  return steps.filter(s => s.status !== 'upcoming')
}
```

## Key Rules

- Log every status change as an event in `order_events` — the timeline derives from events, not a single status column.
- Show estimated dates for future steps — "Estimated delivery: Aug 18" is more useful than just "Delivered: upcoming".
- Cancelled orders should show progress up to the cancellation point, not a blank timeline.
- Mobile: stacked vertical timeline (as above) is better than horizontal for orders with 5+ steps.
- Include tracking number and carrier link in the "Shipped" step description.
