# Chart Patterns

## Library Choice

Use `recharts` — it's React-native, works well with Tailwind, and has TypeScript support. Don't use Chart.js (requires canvas setup) or D3 (too low-level for standard charts).

```bash
npm install recharts
```

## ResponsiveContainer (Required)

Always wrap charts in `ResponsiveContainer` — charts need explicit dimensions, but containers are usually fluid:

```typescript
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip } from 'recharts'

function RevenueChart({ data }: { data: { month: string; revenue: number }[] }) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <LineChart data={data} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
        <XAxis dataKey="month" tick={{ fontSize: 12 }} />
        <YAxis
          tick={{ fontSize: 12 }}
          tickFormatter={(v) => `$${(v / 100).toFixed(0)}`}  // cents → dollars
        />
        <Tooltip
          formatter={(value: number) => [`$${(value / 100).toFixed(2)}`, 'Revenue']}
        />
        <Line
          type="monotone"
          dataKey="revenue"
          stroke="hsl(var(--primary))"
          strokeWidth={2}
          dot={false}
        />
      </LineChart>
    </ResponsiveContainer>
  )
}
```

## Bar Chart

```typescript
import { BarChart, Bar, CartesianGrid, Legend } from 'recharts'

function InvoiceStatusChart({ data }: { data: { status: string; count: number }[] }) {
  return (
    <ResponsiveContainer width="100%" height={200}>
      <BarChart data={data}>
        <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
        <XAxis dataKey="status" />
        <YAxis />
        <Tooltip />
        <Bar dataKey="count" fill="hsl(var(--primary))" radius={[4, 4, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  )
}
```

## Pie / Donut Chart

```typescript
import { PieChart, Pie, Cell, Tooltip, Legend } from 'recharts'

const COLORS = [
  'hsl(var(--chart-1))',
  'hsl(var(--chart-2))',
  'hsl(var(--chart-3))',
  'hsl(var(--chart-4))',
]

function CategoryBreakdown({ data }: { data: { name: string; value: number }[] }) {
  return (
    <ResponsiveContainer width="100%" height={250}>
      <PieChart>
        <Pie
          data={data}
          cx="50%"
          cy="50%"
          innerRadius={60}   // donut: set innerRadius; pie: omit
          outerRadius={90}
          dataKey="value"
          label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
        >
          {data.map((_, i) => (
            <Cell key={i} fill={COLORS[i % COLORS.length]} />
          ))}
        </Pie>
        <Tooltip />
      </PieChart>
    </ResponsiveContainer>
  )
}
```

## Loading State

Charts can't render Skeleton placeholders well — use a pulse div with the same dimensions:

```typescript
function ChartCard({ title, isLoading, children }: {
  title: string
  isLoading: boolean
  children: React.ReactNode
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="h-[300px] bg-muted animate-pulse rounded" />
        ) : (
          children
        )}
      </CardContent>
    </Card>
  )
}
```

## Theming with CSS Variables

Use shadcn/ui CSS variable colors so charts respect dark mode:

```css
/* globals.css */
:root {
  --chart-1: 221 83% 53%;   /* blue */
  --chart-2: 142 71% 45%;   /* green */
  --chart-3: 45 93% 47%;    /* yellow */
  --chart-4: 339 90% 51%;   /* red */
}
```

```typescript
stroke="hsl(var(--chart-1))"
fill="hsl(var(--chart-2))"
```

## Custom Tooltip

Default Tooltip is ugly — replace it:

```typescript
function CustomTooltip({ active, payload, label }: TooltipProps<number, string>) {
  if (!active || !payload?.length) return null
  
  return (
    <div className="bg-popover border rounded-md shadow-md p-3 text-sm">
      <p className="font-medium mb-1">{label}</p>
      {payload.map((entry) => (
        <p key={entry.name} style={{ color: entry.color }}>
          {entry.name}: {formatCurrency(entry.value as number)}
        </p>
      ))}
    </div>
  )
}

// Use it:
<Tooltip content={<CustomTooltip />} />
```

## Data Preparation

Prepare data in a Server Component or TanStack Query — don't do aggregation inside the chart component:

```typescript
// Server Component or loader:
const chartData = invoices
  .reduce<Record<string, number>>((acc, inv) => {
    const month = format(new Date(inv.created_at), 'MMM')
    acc[month] = (acc[month] ?? 0) + inv.total_cents
    return acc
  }, {})
  
const data = Object.entries(chartData).map(([month, revenue]) => ({ month, revenue }))
```
