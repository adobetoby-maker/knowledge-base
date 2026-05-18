# Pattern: Stats/Metric Cards

## Overview

Dashboard cards showing a key metric (number), trend indicator (up/down vs previous period), and context (label, time range). Design decisions: trend color (red/green — is up always good?), number formatting (1.2M not 1234567), and loading skeleton state.

## Component

```tsx
interface StatCardProps {
  label: string
  value: number
  previousValue?: number
  format?: 'number' | 'currency' | 'percent'
  currency?: string
  trend?: 'higher-is-better' | 'lower-is-better'
  loading?: boolean
}

function StatCard({ label, value, previousValue, format = 'number', currency = 'USD', trend = 'higher-is-better', loading = false }: StatCardProps) {
  const change = previousValue !== undefined
    ? ((value - previousValue) / Math.abs(previousValue)) * 100
    : null

  const isPositiveChange = change !== null && change > 0
  // "Higher is better": up = green. "Lower is better": up = red.
  const changeIsGood = trend === 'higher-is-better' ? isPositiveChange : !isPositiveChange

  if (loading) {
    return (
      <div className="bg-white rounded-xl border p-5 space-y-3">
        <div className="h-4 w-24 bg-gray-200 rounded animate-pulse" />
        <div className="h-8 w-32 bg-gray-200 rounded animate-pulse" />
        <div className="h-3 w-20 bg-gray-200 rounded animate-pulse" />
      </div>
    )
  }

  return (
    <div className="bg-white rounded-xl border p-5">
      <p className="text-sm text-gray-500 font-medium">{label}</p>
      <p className="text-2xl font-bold mt-1 text-gray-900">
        {formatMetric(value, format, currency)}
      </p>
      {change !== null && (
        <p className={`text-sm mt-1 flex items-center gap-1 ${changeIsGood ? 'text-green-600' : 'text-red-600'}`}>
          <span>{isPositiveChange ? '↑' : '↓'}</span>
          <span>{Math.abs(change).toFixed(1)}% vs last period</span>
        </p>
      )}
    </div>
  )
}

function formatMetric(value: number, format: string, currency: string): string {
  if (format === 'currency') {
    if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M ${currency}`
    if (value >= 1_000) return `${(value / 1_000).toFixed(1)}K ${currency}`
    return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(value)
  }
  if (format === 'percent') return `${value.toFixed(1)}%`
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)}K`
  return value.toLocaleString()
}
```

## Grid Layout

```tsx
<div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
  <StatCard label="Monthly Revenue" value={142500} previousValue={128000} format="currency" />
  <StatCard label="Active Users" value={8342} previousValue={7100} />
  <StatCard label="Avg. Response Time" value={2.4} previousValue={2.1} format="number" trend="lower-is-better" />
  <StatCard label="Error Rate" value={0.8} previousValue={1.2} format="percent" trend="lower-is-better" />
</div>
```

## Count-Up Animation

```tsx
function AnimatedNumber({ target }: { target: number }) {
  const [displayed, setDisplayed] = useState(0)

  useEffect(() => {
    const duration = 1500  // ms
    const start = Date.now()
    
    function tick() {
      const elapsed = Date.now() - start
      const progress = Math.min(elapsed / duration, 1)
      // Ease out cubic
      const eased = 1 - Math.pow(1 - progress, 3)
      setDisplayed(Math.round(eased * target))
      if (progress < 1) requestAnimationFrame(tick)
    }

    requestAnimationFrame(tick)
  }, [target])

  return <span>{displayed.toLocaleString()}</span>
}
```

## Key Rules

- The `trend` prop is critical: "Error rate going up" is bad even though up = bigger number. Always let the consumer specify.
- Format large numbers as `1.2M` or `42.5K` — raw `1234567` is hard to read at a glance.
- Always show the skeleton loading state — stat cards that pop in cause jarring layout shift.
- For real-time metrics: poll every 30s with stale-while-revalidate. Don't use websockets unless the metric is genuinely real-time (live order count, active connections).
