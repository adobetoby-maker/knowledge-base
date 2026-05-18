# Plugin: Recharts

## What It Is

Recharts is a composable charting library built on React and D3. All charts are React components. Uses an SVG rendering model. Responsive out of the box via `ResponsiveContainer`. The default choice for admin dashboards.

## Installation

```bash
npm install recharts
```

## Import Pattern

Tree-shake by importing only what you use:

```ts
import {
  LineChart, Line,
  BarChart, Bar,
  AreaChart, Area,
  PieChart, Pie, Cell,
  XAxis, YAxis,
  CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts'
```

## Essential: ResponsiveContainer

Always wrap charts in `ResponsiveContainer`. Never hardcode widths:

```tsx
<ResponsiveContainer width="100%" height={240}>
  <LineChart data={data}>
    ...
  </LineChart>
</ResponsiveContainer>
```

`height` must be in pixels (not %). The parent div controls width. Chart components use browser APIs — always `'use client'` or dynamic import with `{ ssr: false }`.

## Line Chart

```tsx
<LineChart data={data} margin={{ top: 5, right: 5, bottom: 5, left: 0 }}>
  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
  <XAxis
    dataKey="date"
    tick={{ fontSize: 12, fill: '#9ca3af' }}
    axisLine={false}
    tickLine={false}
  />
  <YAxis
    tick={{ fontSize: 12, fill: '#9ca3af' }}
    axisLine={false}
    tickLine={false}
    width={50}
  />
  <Tooltip />
  <Line
    type="monotone"     // Smooth line. "linear" for straight segments
    dataKey="value"
    stroke="#2563eb"
    strokeWidth={2}
    dot={false}         // Hide dots for cleaner trend lines
    activeDot={{ r: 4 }}  // Show dot only on hover
  />
</LineChart>
```

## Bar Chart

```tsx
<BarChart data={data} barSize={16} barGap={4}>
  <XAxis dataKey="month" axisLine={false} tickLine={false} tick={{ fontSize: 12 }} />
  <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 12 }} />
  <Tooltip />
  <Bar dataKey="revenue" fill="#2563eb" radius={[4, 4, 0, 0]} />
  <Bar dataKey="expenses" fill="#e5e7eb" radius={[4, 4, 0, 0]} />
</BarChart>
```

`radius={[4, 4, 0, 0]}` — top-left, top-right, bottom-right, bottom-left rounded corners.

## Area Chart (Cumulative / Filled)

```tsx
<AreaChart data={data}>
  <defs>
    <linearGradient id="gradient" x1="0" y1="0" x2="0" y2="1">
      <stop offset="5%" stopColor="#2563eb" stopOpacity={0.15} />
      <stop offset="95%" stopColor="#2563eb" stopOpacity={0} />
    </linearGradient>
  </defs>
  <XAxis dataKey="date" />
  <YAxis />
  <Tooltip />
  <Area
    type="monotone"
    dataKey="value"
    stroke="#2563eb"
    strokeWidth={2}
    fill="url(#gradient)"
  />
</AreaChart>
```

## Pie / Donut Chart

```tsx
<PieChart>
  <Pie
    data={data}
    cx="50%"
    cy="50%"
    innerRadius={40}   // Remove for solid pie; set for donut
    outerRadius={80}
    paddingAngle={2}
    dataKey="value"
    nameKey="name"
  >
    {data.map((entry, i) => (
      <Cell key={i} fill={COLORS[i % COLORS.length]} />
    ))}
  </Pie>
  <Tooltip />
  <Legend />
</PieChart>
```

## Custom Tooltip

```tsx
function CustomTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null

  return (
    <div className="bg-white border rounded-lg shadow-lg px-3 py-2">
      <p className="text-xs text-gray-500 mb-1">{label}</p>
      {payload.map((p: any) => (
        <p key={p.name} className="text-sm font-medium" style={{ color: p.color }}>
          {p.name}: {p.value}
        </p>
      ))}
    </div>
  )
}

<Tooltip content={<CustomTooltip />} />
```

## Tick Formatter

```tsx
<YAxis tickFormatter={(v: number) => `$${(v / 1000).toFixed(0)}k`} />
<XAxis tickFormatter={(d: string) => format(parseISO(d), 'MMM d')} />
```

## Multiple Y Axes

```tsx
<YAxis yAxisId="left" />
<YAxis yAxisId="right" orientation="right" />
<Line yAxisId="left" dataKey="revenue" stroke="#2563eb" />
<Line yAxisId="right" dataKey="count" stroke="#22c55e" />
```

## Common Pitfalls

- `height="100%"` on `ResponsiveContainer` requires explicit parent height — use pixels
- Charts must be client components — never render in RSC
- `data` must be a stable reference — wrap in `useMemo` if derived
- Pie `cx`/`cy` are percentages of the chart width/height, not absolute values
- `ResponsiveContainer` with SSR causes hydration mismatch — use `dynamic(() => ..., { ssr: false })`
