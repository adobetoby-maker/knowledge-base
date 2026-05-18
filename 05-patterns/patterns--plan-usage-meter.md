# Pattern: Plan Usage Meter

## Overview
Usage meters help users understand their consumption relative to plan limits before they hit them. The critical UX detail is progressive urgency: green below 70%, yellow 70–90%, red above 90% with an upgrade prompt. If users only see red when they're at 95%, they've already had a bad experience. The meter should also show the reset date so users know if they should slow down or if the limit resets tomorrow.

## Implementation

### Usage meter component

```tsx
interface UsageMeterProps {
  label: string
  used: number
  limit: number
  unit?: string           // "API calls", "GB", "users"
  resetAt?: string        // ISO date of next reset
  upgradeHref?: string
  formatValue?: (n: number) => string
}

function UsageMeter({
  label,
  used,
  limit,
  unit = '',
  resetAt,
  upgradeHref,
  formatValue = (n) => n.toLocaleString(),
}: UsageMeterProps) {
  const pct = limit > 0 ? Math.min(100, (used / limit) * 100) : 0
  const status = pct >= 90 ? 'critical' : pct >= 70 ? 'warning' : 'ok'

  const barColor = {
    ok:       'bg-green-500',
    warning:  'bg-amber-400',
    critical: 'bg-red-500',
  }[status]

  const textColor = {
    ok:       'text-green-600',
    warning:  'text-amber-600',
    critical: 'text-red-600',
  }[status]

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between text-sm">
        <span className="font-medium text-gray-700">{label}</span>
        <span className={`font-semibold tabular-nums ${textColor}`}>
          {formatValue(used)} / {formatValue(limit)} {unit}
        </span>
      </div>

      {/* Progress bar */}
      <div
        role="progressbar"
        aria-valuenow={Math.round(pct)}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={`${label}: ${Math.round(pct)}% used`}
        className="h-2 bg-gray-100 rounded-full overflow-hidden"
      >
        <div
          className={`h-full rounded-full transition-all duration-300 ${barColor}`}
          style={{ width: `${pct}%` }}
        />
      </div>

      {/* Footer: percentage + reset date + upgrade CTA */}
      <div className="flex items-center justify-between text-xs text-gray-400">
        <span>{Math.round(pct)}% used</span>
        <div className="flex items-center gap-3">
          {resetAt && (
            <span>Resets {formatRelativeDate(resetAt)}</span>
          )}
          {status === 'critical' && upgradeHref && (
            <a
              href={upgradeHref}
              className="text-blue-600 font-medium hover:underline"
            >
              Upgrade for more →
            </a>
          )}
        </div>
      </div>

      {/* Warning banner when approaching limit */}
      {status === 'warning' && upgradeHref && (
        <div className="flex items-center gap-2 text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-md px-3 py-2">
          <AlertTriangle size={12} />
          <span>
            Approaching your limit.{' '}
            <a href={upgradeHref} className="underline font-medium">Upgrade your plan</a>{' '}
            to avoid interruption.
          </span>
        </div>
      )}
    </div>
  )
}
```

### Usage dashboard with multiple meters

```tsx
function PlanUsageDashboard({ plan }: { plan: PlanUsage }) {
  return (
    <div className="rounded-xl border p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="font-semibold text-lg">Plan Usage</h3>
          <p className="text-sm text-gray-500 capitalize">{plan.tier} plan</p>
        </div>
        {plan.tier !== 'enterprise' && (
          <Button variant="outline" size="sm" href="/pricing">Upgrade plan</Button>
        )}
      </div>

      <UsageMeter
        label="API calls"
        used={plan.apiCalls.used}
        limit={plan.apiCalls.limit}
        unit="calls"
        resetAt={plan.resetAt}
        upgradeHref="/pricing"
      />

      <UsageMeter
        label="Storage"
        used={plan.storage.used}
        limit={plan.storage.limit}
        unit="GB"
        resetAt={undefined}  // Storage doesn't reset
        upgradeHref="/pricing"
        formatValue={(n) => n.toFixed(1)}
      />

      <UsageMeter
        label="Team members"
        used={plan.seats.used}
        limit={plan.seats.limit}
        unit="seats"
        upgradeHref="/pricing"
      />
    </div>
  )
}
```

### Relative date helper

```ts
function formatRelativeDate(isoDate: string): string {
  const d = new Date(isoDate)
  const now = new Date()
  const days = Math.ceil((d.getTime() - now.getTime()) / 86400000)

  if (days <= 0) return 'today'
  if (days === 1) return 'tomorrow'
  if (days < 7) return `in ${days} days`
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}
```

## Key Rules
- Show specific counts (`1,234 of 5,000`) not just percentages — percentages alone don't convey scale
- Three color states with clear thresholds: green < 70%, yellow 70–90%, red > 90%
- Show the upgrade CTA when in warning or critical state — not always (don't nag at 10%)
- Reset date is crucial: if the limit resets in 12 hours, the user shouldn't panic at 85%
- `role="progressbar"` with `aria-valuenow` for screen reader compatibility
- Don't show the meter at all if there is no limit (unlimited plan) — an empty bar is confusing
- For "seats" (not resetting) there is no reset date — only show reset date for time-based limits
