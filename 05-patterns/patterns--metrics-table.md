# Pattern: Metrics / Analytics Table

## Overview
Analytics tables need number formatting, trend context, and sparklines to be useful — raw numbers without context answer "what" but not "is this good or bad." Rendering sparklines as inline SVGs avoids external library overhead and gives precise control over the visual. CSV export must happen server-side for large datasets; client-side blob export breaks on tables with thousands of rows.

## Number Formatting

```ts
// Format large numbers with K/M abbreviations — raw 1234567 is unreadable at a glance
function formatMetric(value: number, unit?: 'currency' | 'percent' | 'duration'): string {
  if (unit === 'currency') {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      notation: value >= 1_000_000 ? 'compact' : 'standard',
      maximumFractionDigits: value >= 1_000 ? 1 : 2,
    }).format(value);
  }
  if (unit === 'percent') {
    return `${value.toFixed(1)}%`;
  }
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)}K`;
  return value.toLocaleString();
}

// Delta: show change vs prior period with direction and color
function formatDelta(current: number, prior: number): { text: string; direction: 'up' | 'down' | 'flat' } {
  if (prior === 0) return { text: '—', direction: 'flat' };
  const pct = ((current - prior) / prior) * 100;
  return {
    text: `${pct > 0 ? '+' : ''}${pct.toFixed(1)}%`,
    direction: pct > 0.5 ? 'up' : pct < -0.5 ? 'down' : 'flat',
  };
}
```

## Sparkline Component

```tsx
// Inline SVG sparkline — no dependency, 10–20 data points
// Keep sparklines narrow (80px) and low-profile — they're context, not focus

function Sparkline({ data, positive = 'up' }: { data: number[]; positive?: 'up' | 'down' }) {
  if (data.length < 2) return null;

  const W = 80, H = 24, PAD = 2;
  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1; // Prevent division by zero on flat data

  function x(i: number) { return PAD + (i / (data.length - 1)) * (W - PAD * 2); }
  function y(v: number) { return H - PAD - ((v - min) / range) * (H - PAD * 2); }

  const points = data.map((v, i) => `${x(i)},${y(v)}`).join(' ');
  const isPositive = data[data.length - 1] >= data[0];
  // Color the line based on whether the trend is good or bad
  const color = (positive === 'up' ? isPositive : !isPositive) ? '#22c55e' : '#ef4444';

  return (
    <svg width={W} height={H} aria-hidden="true" style={{ display: 'block' }}>
      <polyline
        points={points}
        fill="none"
        stroke={color}
        strokeWidth={1.5}
        strokeLinejoin="round"
        strokeLinecap="round"
      />
    </svg>
  );
}
```

## Metrics Table Component

```tsx
function MetricsTable({ metrics, dateRange, onDateRangeChange }: Props) {
  const [sortKey, setSortKey] = useState<string>('value');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc');

  function toggleSort(key: string) {
    if (sortKey === key) { setSortDir(d => d === 'asc' ? 'desc' : 'asc'); }
    else { setSortKey(key); setSortDir('desc'); }
  }

  const sorted = [...metrics].sort((a, b) => {
    const mult = sortDir === 'asc' ? 1 : -1;
    return (a[sortKey] - b[sortKey]) * mult;
  });

  return (
    <div className="metrics-table-wrapper">
      <div className="metrics-table-controls">
        <DateRangePicker value={dateRange} onChange={onDateRangeChange} />
        <ExportButton metrics={metrics} dateRange={dateRange} />
      </div>
      <table className="metrics-table">
        <thead>
          <tr>
            <SortableHeader label="Metric" sortKey="name" current={sortKey} dir={sortDir} onSort={toggleSort} />
            <SortableHeader label="Value" sortKey="value" current={sortKey} dir={sortDir} onSort={toggleSort} />
            <th>vs Prior Period</th>
            <th>Trend</th>
          </tr>
        </thead>
        <tbody>
          {sorted.map(row => {
            const delta = formatDelta(row.value, row.priorValue);
            return (
              <tr key={row.key}>
                <td>{row.label}</td>
                <td className="metrics-table__value">{formatMetric(row.value, row.unit)}</td>
                <td>
                  <span className={`delta delta--${delta.direction}`}>
                    {delta.direction === 'up' ? '↑' : delta.direction === 'down' ? '↓' : ''}
                    {delta.text}
                  </span>
                </td>
                <td>
                  <Sparkline data={row.history} positive={row.positiveDirection} />
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
```

## CSV Export

```ts
// Server-side export: GET /api/metrics/export?from=...&to=...
// Client-side CSV blob works for small tables but breaks on large datasets
// Large tables exhaust client memory and the download UI is inconsistent

export async function GET(req: Request) {
  const { from, to } = parseSearchParams(req);
  const metrics = await db.getMetrics({ from, to }); // May be thousands of rows

  const csv = [
    ['Metric', 'Value', 'Prior Value', 'Change %'],
    ...metrics.map(m => [
      m.label,
      m.value,
      m.priorValue,
      ((m.value - m.priorValue) / m.priorValue * 100).toFixed(1),
    ]),
  ].map(row => row.join(',')).join('\n');

  return new Response(csv, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': `attachment; filename="metrics-${from}-${to}.csv"`,
    },
  });
}
```

## Key Rules
- Use `Intl.NumberFormat` with `notation: 'compact'` for large numbers — K/M abbreviations
- Always show delta vs prior period with both direction arrow and percentage text
- Sparklines use `positive` prop to determine good/bad color — revenue up = green; error rate up = red
- Sort on the currently active column only — don't multi-sort without clear UI
- Export as a server-side route returning CSV with `Content-Disposition: attachment`
- Show sparklines as inline SVG — no chart library needed for this scale
- Flat data (all same value) needs a divide-by-zero guard in the sparkline normalizer
