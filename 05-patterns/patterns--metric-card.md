# Pattern: KPI Metric Card

A dashboard card showing a key metric value, trend indicator (up/down with color), percentage and absolute change toggle, sparkline chart, and loading skeleton.

## Why Color-Coded Change Needs Context

Green/red for positive/negative change is intuitive for revenue, conversions, and growth. But for metrics like error rate, churn, or response time, green means "decreased" — the opposite. The component must accept a `positiveDirection` prop rather than hardcoding "up is good."

```tsx
type MetricCardProps = {
  label: string;
  value: number;
  previousValue: number;
  formatter: (n: number) => string;  // e.g., formatCurrency, formatPercent
  positiveDirection: 'up' | 'down';  // 'down' for error rate, churn, etc.
  sparklineData?: number[];
  isLoading?: boolean;
};
```

## Change Calculation

```tsx
function computeChange(current: number, previous: number) {
  if (previous === 0) return { absolute: current, percentage: null };
  const absolute = current - previous;
  const percentage = ((current - previous) / Math.abs(previous)) * 100;
  return { absolute, percentage };
}
```

Handle the `previous === 0` case explicitly — dividing by zero produces `Infinity`, which breaks display.

## Color-Coded Trend with Direction Context

```tsx
function TrendIndicator({ change, positiveDirection }: {
  change: { absolute: number; percentage: number | null };
  positiveDirection: 'up' | 'down';
}) {
  const direction = change.absolute >= 0 ? 'up' : 'down';
  const isPositive = direction === positiveDirection;

  const colorClass = isPositive ? 'text-green-600' : 'text-red-500';
  const Icon = direction === 'up' ? TrendingUpIcon : TrendingDownIcon;

  return (
    <span className={cn('flex items-center gap-1 text-sm font-medium', colorClass)}>
      <Icon size={14} />
      {change.percentage !== null
        ? `${Math.abs(change.percentage).toFixed(1)}%`
        : `${change.absolute >= 0 ? '+' : ''}${change.absolute}`
      }
    </span>
  );
}
```

## Percentage vs Absolute Toggle

```tsx
function MetricCard({ label, value, previousValue, formatter, positiveDirection, sparklineData, isLoading }: MetricCardProps) {
  const [changeMode, setChangeMode] = useState<'percentage' | 'absolute'>('percentage');
  const change = computeChange(value, previousValue);

  if (isLoading) return <MetricCardSkeleton />;

  const changeDisplay = changeMode === 'percentage'
    ? change.percentage !== null ? `${change.percentage >= 0 ? '+' : ''}${change.percentage.toFixed(1)}%` : 'N/A'
    : `${change.absolute >= 0 ? '+' : ''}${formatter(change.absolute)}`;

  return (
    <div className="rounded-xl border bg-card p-5 space-y-3">
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">{label}</p>
        <button
          onClick={() => setChangeMode(m => m === 'percentage' ? 'absolute' : 'percentage')}
          className="text-xs text-muted-foreground hover:text-foreground transition-colors"
          title="Toggle change format"
        >
          {changeMode === 'percentage' ? '%' : '#'}
        </button>
      </div>

      <div className="flex items-end justify-between gap-2">
        <div>
          <p className="text-2xl font-bold tabular-nums">{formatter(value)}</p>
          <div className="flex items-center gap-2 mt-1">
            <TrendIndicator change={change} positiveDirection={positiveDirection} />
            <span className="text-xs text-muted-foreground">vs last period</span>
          </div>
        </div>
        {sparklineData && (
          <div className="w-20 h-10">
            <Sparkline data={sparklineData} isPositive={change.absolute >= 0 && positiveDirection === 'up'} />
          </div>
        )}
      </div>
    </div>
  );
}
```

## Sparkline

A minimal sparkline using SVG paths — no chart library needed for this simple case.

```tsx
function Sparkline({ data, isPositive }: { data: number[]; isPositive: boolean }) {
  if (data.length < 2) return null;

  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;
  const width = 80;
  const height = 40;

  const points = data.map((v, i) => ({
    x: (i / (data.length - 1)) * width,
    y: height - ((v - min) / range) * height,
  }));

  const pathD = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x},${p.y}`).join(' ');
  const color = isPositive ? '#16a34a' : '#ef4444';

  return (
    <svg viewBox={`0 0 ${width} ${height}`} className="w-full h-full overflow-visible">
      <path d={pathD} stroke={color} strokeWidth={1.5} fill="none" />
    </svg>
  );
}
```

## Loading Skeleton

```tsx
function MetricCardSkeleton() {
  return (
    <div className="rounded-xl border bg-card p-5 space-y-3 animate-pulse">
      <div className="h-4 w-24 bg-muted rounded" />
      <div className="h-8 w-32 bg-muted rounded" />
      <div className="h-3 w-20 bg-muted rounded" />
    </div>
  );
}
```

## Tooltip with Detail

Wrap the card or trend indicator in a tooltip showing the raw numbers:

```tsx
<Tooltip content={`${formatter(previousValue)} → ${formatter(value)}`}>
  <TrendIndicator change={change} positiveDirection={positiveDirection} />
</Tooltip>
```

## Key Rules

- Accept `positiveDirection: 'up' | 'down'` — never hardcode "up is green"
- Handle `previousValue === 0` — division by zero produces `Infinity`
- Use `tabular-nums` on metric values — prevents layout shift as numbers update
- The toggle button for %/absolute should be small and subtle — it's secondary to the value itself
- Loading skeleton must match the card's shape exactly to prevent layout shift on data load
- Sparkline color should match the trend indicator color for consistency
