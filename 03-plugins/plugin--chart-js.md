# Plugin: Chart.js (react-chartjs-2)

## Overview

Chart.js is a canvas-based charting library. The React wrapper is `react-chartjs-2`. The key difference from Nivo/Recharts: Chart.js renders to `<canvas>` not SVG, so it performs better for large datasets and animations, but you can't inspect individual elements in DevTools or style via CSS.

## Install

```bash
npm install chart.js react-chartjs-2
```

## Required Registration

Chart.js v3+ uses tree-shaking — you must register only the components you use. Failing to register silently renders nothing.

```ts
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js'

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
  Filler,
)
```

Register once at app startup (e.g., `lib/chartjs.ts`, imported in `_app.tsx` or layout).

## Bar Chart

```tsx
import { Bar } from 'react-chartjs-2'

const data = {
  labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May'],
  datasets: [
    {
      label: 'Revenue',
      data: [12000, 19000, 15000, 22000, 18000],
      backgroundColor: 'rgba(59, 130, 246, 0.8)',
      borderColor: 'rgb(59, 130, 246)',
      borderWidth: 1,
      borderRadius: 4,
    },
  ],
}

const options = {
  responsive: true,
  maintainAspectRatio: false,  // Required when container has explicit height
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        label: (ctx) => `$${ctx.parsed.y.toLocaleString()}`,
      },
    },
  },
  scales: {
    y: {
      beginAtZero: true,
      ticks: { callback: (v) => `$${(v / 1000).toFixed(0)}k` },
    },
  },
}

export function RevenueChart() {
  return (
    <div style={{ height: 300 }}>
      <Bar data={data} options={options} />
    </div>
  )
}
```

## Line Chart with Area Fill

```tsx
import { Line } from 'react-chartjs-2'

const lineData = {
  labels: dates,
  datasets: [
    {
      label: 'Users',
      data: counts,
      borderColor: 'rgb(16, 185, 129)',
      backgroundColor: 'rgba(16, 185, 129, 0.1)',
      fill: true,
      tension: 0.4,
      pointRadius: 0,
      pointHoverRadius: 4,
    },
  ],
}
```

## Doughnut Chart

```tsx
import { Doughnut } from 'react-chartjs-2'

const donutData = {
  labels: ['Direct', 'Organic', 'Social', 'Email'],
  datasets: [
    {
      data: [30, 45, 15, 10],
      backgroundColor: ['#3b82f6', '#10b981', '#f59e0b', '#ef4444'],
      borderWidth: 0,
      hoverOffset: 4,
    },
  ],
}

<Doughnut
  data={donutData}
  options={{
    responsive: true,
    maintainAspectRatio: false,
    cutout: '70%',
    plugins: {
      legend: { position: 'right' },
    },
  }}
/>
```

## Updating Data Dynamically

```tsx
const chartRef = useRef<ChartJS<'line'>>(null)

function updateData(newData: number[]) {
  if (!chartRef.current) return
  chartRef.current.data.datasets[0].data = newData
  chartRef.current.update('active')
}

<Line ref={chartRef} data={data} options={options} />
```

For real-time charts, call `chartRef.current.update()` directly — re-rendering the component causes flicker.

## Custom External Tooltip (HTML)

```ts
const options = {
  plugins: {
    tooltip: {
      enabled: false,
      external: ({ chart, tooltip }) => {
        let el = document.getElementById('chartjs-tooltip')
        if (!el) {
          el = document.createElement('div')
          el.id = 'chartjs-tooltip'
          el.className = 'bg-white shadow rounded px-3 py-2 text-sm pointer-events-none absolute'
          document.body.appendChild(el)
        }
        if (tooltip.opacity === 0) {
          el.style.opacity = '0'
          return
        }
        // Build tooltip content using safe DOM methods
        el.textContent = ''
        const line = document.createElement('p')
        line.textContent = tooltip.body[0]?.lines[0] ?? ''
        el.appendChild(line)

        const { offsetLeft, offsetTop } = chart.canvas
        el.style.left = `${offsetLeft + tooltip.caretX}px`
        el.style.top = `${offsetTop + tooltip.caretY}px`
        el.style.opacity = '1'
      },
    },
  },
}
```

Use `textContent` and `createElement`/`appendChild` for tooltip content — avoid setting raw HTML strings.

## Key Rules

- Register all needed Chart.js components in a single call at startup — missing a registration silently renders a blank canvas.
- Always wrap charts in a container with explicit height and set `maintainAspectRatio: false` — otherwise Chart.js ignores the container height.
- For live-updating charts (WebSocket data), mutate via `chartRef.current` rather than re-rendering — React re-renders reset the canvas animation.
- Canvas-based charts can't be styled with CSS selectors — control all visual styling through the options object.
- `tension: 0.4` for line charts improves readability for smooth trends; use `tension: 0` for data where exact values between points shouldn't be implied.
