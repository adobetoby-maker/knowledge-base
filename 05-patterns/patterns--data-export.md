# Pattern: Data Export (CSV / Excel / JSON)

## What This Solves

Users need to download table data. Three formats matter: CSV (universal), Excel (.xlsx for non-technical users), JSON (for developer/API consumers). The wrong approach is loading everything into a React component and exporting from the DOM — that caps you at whatever's rendered on screen. The right approach is a Route Handler that streams data directly from the DB.

## CSV Export (Route Handler)

```ts
// app/api/invoices/export/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { supabaseAdmin } from '@/lib/supabase/admin'

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const from = searchParams.get('from')
  const to = searchParams.get('to')

  let query = supabaseAdmin
    .from('invoices')
    .select('number, client_name, total_cents, status, created_at')
    .order('created_at', { ascending: false })

  if (from) query = query.gte('created_at', from)
  if (to) query = query.lte('created_at', to)

  const { data, error } = await query

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })

  const rows = data.map(row => ({
    Number: row.number,
    Client: row.client_name,
    'Total (USD)': (row.total_cents / 100).toFixed(2),
    Status: row.status,
    Date: new Date(row.created_at).toLocaleDateString(),
  }))

  const csv = [
    Object.keys(rows[0]).join(','),
    ...rows.map(r => Object.values(r).map(v => `"${String(v).replace(/"/g, '""')}"`).join(','))
  ].join('\n')

  return new NextResponse(csv, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': `attachment; filename="invoices-${Date.now()}.csv"`,
    },
  })
}
```

## Client-Side Trigger

```tsx
function ExportButton() {
  const [exporting, setExporting] = useState(false)

  const handleExport = async () => {
    setExporting(true)
    try {
      const res = await fetch('/api/invoices/export')
      const blob = await res.blob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `invoices-${Date.now()}.csv`
      a.click()
      URL.revokeObjectURL(url)
    } finally {
      setExporting(false)
    }
  }

  return (
    <Button onClick={handleExport} disabled={exporting} variant="outline">
      {exporting ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <Download className="h-4 w-4 mr-2" />}
      Export CSV
    </Button>
  )
}
```

## Excel Export (xlsx)

For Excel, use the `xlsx` package server-side:

```ts
import * as XLSX from 'xlsx'

// Inside the Route Handler:
const wb = XLSX.utils.book_new()
const ws = XLSX.utils.json_to_sheet(rows)
XLSX.utils.book_append_sheet(wb, ws, 'Invoices')
const buffer = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' })

return new NextResponse(buffer, {
  headers: {
    'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'Content-Disposition': `attachment; filename="invoices.xlsx"`,
  },
})
```

## Large Dataset Streaming

For exports > 10k rows, stream rather than buffer:

```ts
export async function GET() {
  const encoder = new TextEncoder()

  const stream = new ReadableStream({
    async start(controller) {
      // Write header
      controller.enqueue(encoder.encode('Number,Client,Total,Status\n'))

      let offset = 0
      const PAGE = 1000

      while (true) {
        const { data } = await supabaseAdmin
          .from('invoices')
          .select('number, client_name, total_cents, status')
          .range(offset, offset + PAGE - 1)

        if (!data || data.length === 0) break

        for (const row of data) {
          const line = `"${row.number}","${row.client_name}",${(row.total_cents / 100).toFixed(2)},"${row.status}"\n`
          controller.enqueue(encoder.encode(line))
        }

        if (data.length < PAGE) break
        offset += PAGE
      }

      controller.close()
    },
  })

  return new NextResponse(stream, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': 'attachment; filename="export.csv"',
    },
  })
}
```

## CSV Value Safety

Always wrap each value in quotes and escape internal quotes:
```ts
const escape = (v: unknown) => `"${String(v ?? '').replace(/"/g, '""')}"`
```

Commas in values, newlines in addresses, and special characters all break naive CSV without this.

## Auth Protection

Export routes contain sensitive data. Always verify the session in the Route Handler before returning data. Do not rely on UI-level disabling of the export button.
