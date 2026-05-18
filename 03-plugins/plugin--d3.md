# Plugin: D3.js in React

## Overview

D3 handles data binding, scales, layouts, and path generation. In React apps, use D3 for math/layout only and React for rendering — don't use D3's DOM manipulation (`d3.select`, `d3.append`) because it fights React's virtual DOM. The exception: axes, where D3's DOM manipulation is easier.

## Setup

```bash
npm install d3
npm install @types/d3
```

## Core Pattern: D3 for Math, React for DOM

```tsx
import * as d3 from 'd3'

interface DataPoint { date: Date; value: number }

function LineChart({ data, width = 600, height = 300 }: {
  data: DataPoint[]
  width?: number
  height?: number
}) {
  const margin = { top: 20, right: 20, bottom: 30, left: 40 }
  const innerWidth = width - margin.left - margin.right
  const innerHeight = height - margin.top - margin.bottom

  // D3 handles scales (math only — no DOM)
  const xScale = d3.scaleTime()
    .domain(d3.extent(data, d => d.date) as [Date, Date])
    .range([0, innerWidth])

  const yScale = d3.scaleLinear()
    .domain([0, d3.max(data, d => d.value)!])
    .nice()
    .range([innerHeight, 0])

  // D3 generates path string
  const line = d3.line<DataPoint>()
    .x(d => xScale(d.date))
    .y(d => yScale(d.value))
    .curve(d3.curveMonotoneX)

  return (
    <svg width={width} height={height}>
      <g transform={`translate(${margin.left},${margin.top})`}>
        {/* Grid lines */}
        {yScale.ticks(5).map(tick => (
          <line
            key={tick}
            x1={0} x2={innerWidth}
            y1={yScale(tick)} y2={yScale(tick)}
            stroke="#e5e7eb" strokeWidth={1}
          />
        ))}
        {/* Data path */}
        <path
          d={line(data) ?? ''}
          fill="none"
          stroke="#3b82f6"
          strokeWidth={2}
        />
        {/* Axes — exception: use D3 DOM for these */}
        <XAxis scale={xScale} height={innerHeight} />
        <YAxis scale={yScale} />
      </g>
    </svg>
  )
}
```

## Axes (D3 DOM Exception)

```tsx
function XAxis({ scale, height }: { scale: d3.ScaleTime<number, number>; height: number }) {
  const ref = useRef<SVGGElement>(null)

  useEffect(() => {
    if (!ref.current) return
    d3.select(ref.current)
      .call(d3.axisBottom(scale).ticks(5).tickFormat(d3.timeFormat('%b %d') as () => string))
      .call(g => g.select('.domain').remove())  // Remove axis line
  }, [scale])

  return <g ref={ref} transform={`translate(0,${height})`} />
}
```

Axes are the one place where D3 DOM is acceptable — they're complex to replicate in React.

## Common D3 Utilities (No DOM)

```ts
// Scales
d3.scaleLinear().domain([0, 100]).range([0, 400])
d3.scaleLog().domain([1, 1000]).range([0, 400])
d3.scaleBand().domain(['A', 'B', 'C']).range([0, 300]).padding(0.1)
d3.scaleOrdinal(d3.schemeCategory10)  // 10-color palette

// Extent and statistics
d3.extent(data, d => d.value)  // [min, max]
d3.min(data, d => d.value)
d3.max(data, d => d.value)
d3.sum(data, d => d.value)
d3.mean(data, d => d.value)

// Data manipulation
d3.groups(data, d => d.category)  // Group by field
d3.rollup(data, v => d3.sum(v, d => d.value), d => d.category)  // Aggregate

// Pie layout
const pie = d3.pie<DataItem>().value(d => d.value)
const arcs = pie(data)  // Returns arc data with startAngle, endAngle

// Arc path generator
const arc = d3.arc<d3.PieArcDatum<DataItem>>()
  .innerRadius(60)  // 0 for pie, >0 for donut
  .outerRadius(120)
const pathD = arc(arcDatum)
```

## Responsive with ResizeObserver

```tsx
function ResponsiveChart({ data }: { data: DataPoint[] }) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [dimensions, setDimensions] = useState({ width: 0, height: 0 })

  useEffect(() => {
    const observer = new ResizeObserver(entries => {
      const { width, height } = entries[0].contentRect
      setDimensions({ width, height })
    })
    if (containerRef.current) observer.observe(containerRef.current)
    return () => observer.disconnect()
  }, [])

  return (
    <div ref={containerRef} className="w-full h-64">
      {dimensions.width > 0 && (
        <LineChart data={data} width={dimensions.width} height={dimensions.height} />
      )}
    </div>
  )
}
```

## Key Rules

- Use D3 for scales, layouts, and path generators — not for DOM manipulation.
- D3 axes are the exception — they're complex enough that D3 DOM is worth it.
- `useEffect` for axes — they need a DOM ref; always include the scale in the dependency array.
- `nice()` on scales rounds the domain to clean numbers for axis labels.
- For standard charts (bar, line, pie), consider Recharts or Nivo instead — they wrap D3 in React-native components with less boilerplate.
