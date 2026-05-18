# Disambig: Which Chart Library to Use

## Decision Matrix

| Library | Bundle | Learning curve | Best for |
|---------|--------|---------------|---------|
| Recharts | ~130KB | Low | Most dashboards |
| Chart.js | ~200KB | Medium | Non-React apps, complex charts |
| Victory | ~90KB | Low | Mobile-first, React Native |
| visx (AirBnB) | ~50KB (treeshake) | High | Custom data viz |
| Nivo | ~180KB | Medium | D3-backed, many chart types |
| `<canvas>` manual | 0KB | Very high | Unique/custom charts |

## Choose Recharts When

- Building a standard admin dashboard (line, bar, pie charts)
- Need responsive charts (ResponsiveContainer)
- Want React-native composition (no imperative API)
- Team knows Recharts or D3 is unfamiliar
- Timeline: fast — most charts are built in 1-2 hours

## Choose Chart.js When

- Existing codebase uses Chart.js
- Need advanced chart types (radar, bubble, scatter)
- Working with non-React (plain HTML/vanilla JS)
- Need `react-chartjs-2` for React wrapper (maintained separately)

## Choose visx When

- Need pixel-perfect custom visualizations
- Building something Chart.js/Recharts can't express
- Team has D3 experience
- Performance is critical (smallest bundle, no abstraction overhead)

## Choose Nivo When

- Need responsive + animated D3 charts
- Want NetworkChart, TreeMap, Sunburst, or Chord charts
- Don't mind the larger bundle
- Need built-in tooltips with good defaults

## Don't Use CSS-Only Charts For

CSS bar charts (`width: ${pct}%`) are fine for simple progress bars. Not for:
- Multiple datasets
- Interactive tooltips
- Axis labels
- Anything that needs to scale beyond a single metric

## Recharts Quick-Start Checklist

1. Install: `npm install recharts`
2. Wrap in `ResponsiveContainer` (always)
3. Set `height` in pixels on `ResponsiveContainer` (not percent — needs explicit parent)
4. Use `axisLine={false} tickLine={false}` for clean axes
5. Use `dot={false}` on `Line` for cleaner trends
6. Custom tooltip via `content={<MyTooltip />}` prop

## Bundle Size Concern

Recharts ~130KB adds meaningfully to bundle. Lazy-load chart components:

```ts
const RevenueChart = dynamic(
  () => import('@/components/charts/RevenueChart'),
  { ssr: false }  // Charts use browser APIs; can't SSR
)
```

Never SSR chart components — they rely on `window.innerWidth` for ResponsiveContainer.
