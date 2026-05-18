# Skill: Reporting Dashboard

## What This Covers

Metrics dashboard with date filtering, KPI cards, charts, and export. Business intelligence layer on top of existing data.

## KPI Card Data Pattern

```ts
// lib/reports/kpis.ts
interface KPIMetrics {
  revenue: {
    current: number   // Current period cents
    previous: number  // Previous period cents
    change: number    // Percentage change
  }
  invoices: { sent: number; paid: number; overdue: number }
  avgDaysToPayment: number
}

async function getKPIs(from: string, to: string, userId: string): Promise<KPIMetrics> {
  // Calculate previous period (same duration)
  const periodMs = new Date(to).getTime() - new Date(from).getTime()
  const prevFrom = new Date(new Date(from).getTime() - periodMs).toISOString()
  const prevTo = from  // Previous period ends where current begins

  const [current, previous, invoiceStats, paymentStats] = await Promise.all([
    supabase.rpc('sum_paid_invoices', { user_id: userId, from_date: from, to_date: to }),
    supabase.rpc('sum_paid_invoices', { user_id: userId, from_date: prevFrom, to_date: prevTo }),
    supabase.rpc('invoice_status_counts', { user_id: userId, from_date: from, to_date: to }),
    supabase.rpc('avg_days_to_payment', { user_id: userId, from_date: from, to_date: to }),
  ])

  const curr = current.data ?? 0
  const prev = previous.data ?? 0
  const change = prev === 0 ? 0 : ((curr - prev) / prev) * 100

  return {
    revenue: { current: curr, previous: prev, change },
    invoices: invoiceStats.data ?? { sent: 0, paid: 0, overdue: 0 },
    avgDaysToPayment: paymentStats.data ?? 0,
  }
}
```

## SQL Aggregate Functions

```sql
-- Sum paid invoices in period
CREATE OR REPLACE FUNCTION sum_paid_invoices(user_id UUID, from_date TIMESTAMPTZ, to_date TIMESTAMPTZ)
RETURNS BIGINT AS $$
  SELECT COALESCE(SUM(total_cents), 0)::BIGINT
  FROM invoices
  WHERE invoices.user_id = sum_paid_invoices.user_id
    AND status = 'paid'
    AND paid_at BETWEEN from_date AND to_date;
$$ LANGUAGE sql SECURITY DEFINER;

-- Revenue by day for chart
CREATE OR REPLACE FUNCTION revenue_by_day(user_id UUID, from_date DATE, to_date DATE)
RETURNS TABLE(day DATE, revenue_cents BIGINT) AS $$
  SELECT
    DATE(paid_at) AS day,
    SUM(total_cents)::BIGINT AS revenue_cents
  FROM invoices
  WHERE invoices.user_id = revenue_by_day.user_id
    AND status = 'paid'
    AND DATE(paid_at) BETWEEN from_date AND to_date
  GROUP BY DATE(paid_at)
  ORDER BY day;
$$ LANGUAGE sql SECURITY DEFINER;
```

## KPI Card Component

```tsx
interface KPICardProps {
  title: string
  value: string
  change?: number  // Percentage change from previous period
  icon?: React.ReactNode
}

function KPICard({ title, value, change, icon }: KPICardProps) {
  const isPositive = (change ?? 0) >= 0

  return (
    <div className="bg-white rounded-xl p-6 border">
      <div className="flex items-center justify-between mb-3">
        <p className="text-sm text-gray-500">{title}</p>
        {icon && <div className="text-gray-400">{icon}</div>}
      </div>
      <p className="text-3xl font-bold text-gray-900">{value}</p>
      {change !== undefined && (
        <div className={`flex items-center gap-1 mt-2 text-sm ${isPositive ? 'text-green-600' : 'text-red-600'}`}>
          <span>{isPositive ? '↑' : '↓'}</span>
          <span>{Math.abs(change).toFixed(1)}% vs last period</span>
        </div>
      )}
    </div>
  )
}
```

## Date Range Picker with Presets

```tsx
'use client'
import { useState } from 'react'
import { subDays, subMonths, startOfMonth, endOfMonth, format } from 'date-fns'

type DatePreset = '7d' | '30d' | '90d' | 'this-month' | 'last-month'

function getPresetRange(preset: DatePreset): { from: Date; to: Date } {
  const today = new Date()
  switch (preset) {
    case '7d': return { from: subDays(today, 7), to: today }
    case '30d': return { from: subDays(today, 30), to: today }
    case '90d': return { from: subDays(today, 90), to: today }
    case 'this-month': return { from: startOfMonth(today), to: endOfMonth(today) }
    case 'last-month': {
      const lastMonth = subMonths(today, 1)
      return { from: startOfMonth(lastMonth), to: endOfMonth(lastMonth) }
    }
  }
}

function DateRangePicker({ onChange }: { onChange: (from: string, to: string) => void }) {
  const [active, setActive] = useState<DatePreset>('30d')

  function select(preset: DatePreset) {
    setActive(preset)
    const { from, to } = getPresetRange(preset)
    onChange(from.toISOString(), to.toISOString())
  }

  const presets: { value: DatePreset; label: string }[] = [
    { value: '7d', label: '7D' },
    { value: '30d', label: '30D' },
    { value: '90d', label: '90D' },
    { value: 'this-month', label: 'This Month' },
    { value: 'last-month', label: 'Last Month' },
  ]

  return (
    <div className="flex gap-1">
      {presets.map((p) => (
        <button
          key={p.value}
          onClick={() => select(p.value)}
          className={`px-3 py-1.5 text-sm rounded-lg ${
            active === p.value
              ? 'bg-blue-600 text-white'
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
          }`}
        >
          {p.label}
        </button>
      ))}
    </div>
  )
}
```

## Chart Integration (Recharts)

```bash
npm install recharts
```

```tsx
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts'
import { format, parseISO } from 'date-fns'

interface RevenuePoint { day: string; revenue_cents: number }

function RevenueChart({ data }: { data: RevenuePoint[] }) {
  const chartData = data.map((d) => ({
    date: format(parseISO(d.day), 'MMM d'),
    revenue: d.revenue_cents / 100,
  }))

  return (
    <div className="bg-white rounded-xl border p-6">
      <h3 className="font-semibold mb-4">Revenue</h3>
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={chartData}>
          <XAxis dataKey="date" tick={{ fontSize: 12 }} />
          <YAxis
            tickFormatter={(v) => `$${v}`}
            tick={{ fontSize: 12 }}
            width={60}
          />
          <Tooltip formatter={(v) => [`$${(v as number).toFixed(2)}`, 'Revenue']} />
          <Line type="monotone" dataKey="revenue" stroke="#2563eb" strokeWidth={2} dot={false} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
```

## URL State for Date Range

```ts
// Persist selected range in URL — shareable reports
const searchParams = useSearchParams()
const router = useRouter()

const from = searchParams.get('from') ?? subDays(new Date(), 30).toISOString()
const to = searchParams.get('to') ?? new Date().toISOString()

function updateDateRange(newFrom: string, newTo: string) {
  const params = new URLSearchParams({ from: newFrom, to: newTo })
  router.push(`?${params}`, { scroll: false })
}
```
