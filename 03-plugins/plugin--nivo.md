# Plugin: Nivo

## Overview

Nivo is a D3-based React charting library with built-in responsive wrappers and server-side rendering support. Unlike recharts (simple) and D3 (complex), Nivo hits the middle ground: rich built-in themes, animated transitions, and composable chart primitives. Use for: admin dashboards, analytics UIs, data-heavy reports.

## Installation

```bash
# Install only the chart types you need
npm install @nivo/core @nivo/line @nivo/bar @nivo/pie @nivo/stream
```

## Bar Chart

```tsx
import { ResponsiveBar } from '@nivo/bar'

const data = [
  { month: 'Jan', revenue: 12000, orders: 45 },
  { month: 'Feb', revenue: 18000, orders: 67 },
  { month: 'Mar', revenue: 15000, orders: 58 },
]

export function RevenueBarChart() {
  return (
    <div style={{ height: 300 }}>
      <ResponsiveBar
        data={data}
        keys={['revenue', 'orders']}
        indexBy="month"
        margin={{ top: 20, right: 20, bottom: 40, left: 60 }}
        padding={0.3}
        groupMode="grouped"
        colors={{ scheme: 'blue_green' }}
        axisBottom={{
          tickSize: 0,
          tickPadding: 8,
        }}
        axisLeft={{
          tickSize: 0,
          tickPadding: 8,
          format: (v) => `$${(v / 1000).toFixed(0)}K`,
        }}
        enableLabel={false}
        tooltip={({ id, value, indexValue }) => (
          <div className="bg-white border rounded px-3 py-2 shadow text-sm">
            <strong>{indexValue}</strong> — {id}: {value}
          </div>
        )}
      />
    </div>
  )
}
```

## Line Chart

```tsx
import { ResponsiveLine } from '@nivo/line'

interface DataPoint {
  x: string
  y: number
}

interface Series {
  id: string
  data: DataPoint[]
}

export function TrendLineChart({ data }: { data: Series[] }) {
  return (
    <div style={{ height: 250 }}>
      <ResponsiveLine
        data={data}
        margin={{ top: 10, right: 30, bottom: 50, left: 60 }}
        xScale={{ type: 'point' }}
        yScale={{ type: 'linear', min: 'auto', max: 'auto' }}
        axisBottom={{ tickRotation: -45 }}
        axisLeft={{ format: (v) => `${v}` }}
        colors={{ scheme: 'category10' }}
        lineWidth={2}
        enablePoints={true}
        pointSize={6}
        enableSlices="x"  // Shared crosshair tooltip on hover
        useMesh={true}
        curve="monotoneX"
      />
    </div>
  )
}
```

## Pie Chart

```tsx
import { ResponsivePie } from '@nivo/pie'

const segments = [
  { id: 'Electronics', value: 42, label: 'Electronics' },
  { id: 'Clothing', value: 31, label: 'Clothing' },
  { id: 'Books', value: 27, label: 'Books' },
]

export function CategoryPieChart() {
  return (
    <div style={{ height: 280 }}>
      <ResponsivePie
        data={segments}
        margin={{ top: 20, right: 80, bottom: 20, left: 80 }}
        innerRadius={0.55}       // Donut chart
        padAngle={0.7}
        cornerRadius={3}
        colors={{ scheme: 'blues' }}
        arcLinkLabelsThreshold={0.05}
        arcLinkLabelsTextColor="#374151"
        legends={[
          {
            anchor: 'bottom',
            direction: 'row',
            translateY: 56,
            itemWidth: 100,
            itemHeight: 18,
            symbolSize: 12,
            symbolShape: 'circle',
          },
        ]}
        tooltip={({ datum }) => (
          <div className="bg-white border rounded px-2 py-1 text-sm shadow">
            {datum.label}: <strong>{datum.value}%</strong>
          </div>
        )}
      />
    </div>
  )
}
```

## Custom Theme

```ts
const nivoTheme = {
  textColor: '#374151',
  fontSize: 12,
  axis: {
    domain: { line: { stroke: '#e5e7eb' } },
    ticks: { line: { stroke: '#e5e7eb' } },
  },
  grid: { line: { stroke: '#f3f4f6' } },
  tooltip: {
    container: {
      background: '#fff',
      border: '1px solid #e5e7eb',
      borderRadius: 6,
      boxShadow: '0 2px 8px rgba(0,0,0,0.08)',
      fontSize: 12,
      padding: '8px 12px',
    },
  },
}

<ResponsiveBar theme={nivoTheme} ... />
```

## SSR / Next.js

Nivo uses browser APIs — must be client-side:

```tsx
// Mark the chart component
'use client'
import { ResponsiveBar } from '@nivo/bar'
```

Or dynamic import for pages that mix server and client:

```tsx
const RevenueChart = dynamic(() => import('@/components/RevenueBarChart'), { ssr: false })
```

## Key Rules

- Always wrap charts in a container with explicit `height` — `ResponsiveBar` needs a measured height, not `height: 100%` with an unknown parent.
- `enableLabel={false}` for bar charts with many bars — labels overlap and become unreadable.
- `enableSlices="x"` on line charts shows a crosshair tooltip at the hovered x-axis point — better UX than per-point tooltips.
- Custom `tooltip` components should be simple React JSX — avoid complex state inside tooltips (they re-render on every hover).
- Nivo animations are enabled by default — disable with `animate={false}` on dashboards that update frequently to avoid jank.
