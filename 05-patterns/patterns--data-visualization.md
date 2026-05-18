# Pattern: Data Visualization (Recharts)

## Library

Recharts is a composable charting library built on React and D3. Tree-shakeable — import only the chart types you use. Works with Tailwind. Alternative: `chart.js` (more features, less React-native), `victory`, `visx` (D3 direct).

```bash
npm install recharts
```

## Common Chart Types

| Chart | When to use |
|-------|------------|
| `LineChart` | Trends over time (revenue, signups) |
| `BarChart` | Comparisons (sales by month, category breakdown) |
| `AreaChart` | Cumulative values (running total) |
| `PieChart` / `RadialBarChart` | Distribution (status breakdown, share) |
| `ComposedChart` | Mix line + bar on same axes |

## Line Chart — Revenue Trend

```tsx
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, Legend
} from 'recharts'
import { format, parseISO } from 'date-fns'

interface DataPoint {
  date: string       // ISO date
  revenue: number    // In dollars (after dividing cents)
}

function RevenueChart({ data }: { data: DataPoint[] }) {
  return (
    <div className="bg-white rounded-xl border p-6">
      <h3 className="font-semibold text-gray-900 mb-4">Revenue</h3>
      <ResponsiveContainer width="100%" height={240}>
        <LineChart data={data} margin={{ top: 5, right: 5, bottom: 5, left: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis
            dataKey="date"
            tickFormatter={(d) => format(parseISO(d), 'MMM d')}
            tick={{ fontSize: 12, fill: '#9ca3af' }}
            axisLine={false}
            tickLine={false}
          />
          <YAxis
            tickFormatter={(v) => `$${v}`}
            tick={{ fontSize: 12, fill: '#9ca3af' }}
            axisLine={false}
            tickLine={false}
            width={50}
          />
          <Tooltip
            formatter={(value) => [`$${(value as number).toFixed(2)}`, 'Revenue']}
            labelFormatter={(d) => format(parseISO(d as string), 'MMMM d, yyyy')}
            contentStyle={{ borderRadius: '8px', border: '1px solid #e5e7eb' }}
          />
          <Line
            type="monotone"
            dataKey="revenue"
            stroke="#2563eb"
            strokeWidth={2}
            dot={false}
            activeDot={{ r: 4 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
```

## Bar Chart — Monthly Comparison

```tsx
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts'

interface MonthlyData {
  month: string     // "Jan", "Feb"
  invoices: number
  paid: number
}

function MonthlyBarChart({ data }: { data: MonthlyData[] }) {
  return (
    <ResponsiveContainer width="100%" height={200}>
      <BarChart data={data} barSize={20} barGap={4}>
        <XAxis dataKey="month" tick={{ fontSize: 12 }} axisLine={false} tickLine={false} />
        <YAxis tick={{ fontSize: 12 }} axisLine={false} tickLine={false} />
        <Tooltip />
        <Bar dataKey="invoices" fill="#e5e7eb" name="Sent" radius={[4, 4, 0, 0]} />
        <Bar dataKey="paid" fill="#2563eb" name="Paid" radius={[4, 4, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  )
}
```

## Pie Chart — Status Distribution

```tsx
import { PieChart, Pie, Cell, Tooltip, Legend } from 'recharts'

const STATUS_COLORS = {
  paid: '#22c55e',
  sent: '#3b82f6',
  draft: '#9ca3af',
  overdue: '#ef4444',
}

function StatusPie({ data }: { data: { name: string; value: number }[] }) {
  return (
    <PieChart width={200} height={200}>
      <Pie
        data={data}
        cx="50%"
        cy="50%"
        innerRadius={50}  // Donut style
        outerRadius={80}
        paddingAngle={2}
        dataKey="value"
      >
        {data.map((entry) => (
          <Cell
            key={entry.name}
            fill={STATUS_COLORS[entry.name as keyof typeof STATUS_COLORS] ?? '#9ca3af'}
          />
        ))}
      </Pie>
      <Tooltip formatter={(v) => [v, '']} />
    </PieChart>
  )
}
```

## Composed Chart (Line + Bar)

```tsx
import { ComposedChart, Bar, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts'

function ComposedExample({ data }: { data: any[] }) {
  return (
    <ResponsiveContainer width="100%" height={240}>
      <ComposedChart data={data}>
        <XAxis dataKey="month" />
        <YAxis yAxisId="left" />
        <YAxis yAxisId="right" orientation="right" />
        <Tooltip />
        <Bar yAxisId="left" dataKey="invoiceCount" fill="#e5e7eb" name="Invoices" />
        <Line yAxisId="right" type="monotone" dataKey="revenue" stroke="#2563eb" strokeWidth={2} dot={false} />
      </ComposedChart>
    </ResponsiveContainer>
  )
}
```

## Custom Tooltip

```tsx
function CustomTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null

  return (
    <div className="bg-white border rounded-lg shadow-lg p-3">
      <p className="font-medium text-sm mb-1">{label}</p>
      {payload.map((entry: any) => (
        <p key={entry.name} className="text-sm" style={{ color: entry.color }}>
          {entry.name}: {typeof entry.value === 'number' ? `$${entry.value.toFixed(2)}` : entry.value}
        </p>
      ))}
    </div>
  )
}

// In chart
<Tooltip content={<CustomTooltip />} />
```

## Responsive Sizing

Always use `ResponsiveContainer` — never hardcode pixel widths:

```tsx
<ResponsiveContainer width="100%" height={240}>
  <LineChart ...>
```

The parent container controls the width. Set height in pixels (not percent) — `100%` height requires a parent with an explicit height.

## Empty State

```tsx
{data.length === 0 ? (
  <div className="flex items-center justify-center h-40 text-gray-400 text-sm">
    No data for this period
  </div>
) : (
  <ResponsiveContainer width="100%" height={240}>
    <LineChart data={data}>...
  </ResponsiveContainer>
)}
```
