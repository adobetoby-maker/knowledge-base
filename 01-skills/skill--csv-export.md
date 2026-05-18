# CSV Export

## When to Use CSV Export

CSV export is appropriate for:
- Admin panel data exports (all invoices, customer list)
- Bulk data downloads for analysis
- Import into other systems (QuickBooks, Excel)

Not appropriate for:
- Sensitive data that shouldn't leave the server (use filtered exports)
- Real-time data that needs live sync (use API or webhooks)

## Basic CSV Route Handler

```typescript
// app/api/admin/export/invoices/route.ts
import { createAdminClient } from '@/lib/supabase/admin'
import { validateAdminSession } from '@/lib/adminAuth'

export async function GET(req: NextRequest) {
  // Admin-only endpoint
  const isAdmin = await validateAdminSession(req)
  if (!isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const supabase = createAdminClient()
  const { data: invoices } = await supabase
    .from('invoices')
    .select('id, number, customer_name, total, status, created_at')
    .order('created_at', { ascending: false })

  if (!invoices) return NextResponse.json({ error: 'Failed to fetch' }, { status: 500 })

  const csv = generateCSV(invoices, [
    { key: 'number', label: 'Invoice #' },
    { key: 'customer_name', label: 'Customer' },
    { key: 'total', label: 'Amount', format: (v) => `$${Number(v).toFixed(2)}` },
    { key: 'status', label: 'Status' },
    { key: 'created_at', label: 'Date', format: (v) => new Date(v as string).toLocaleDateString('en-US') },
  ])

  return new Response(csv, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': `attachment; filename="invoices-${new Date().toISOString().split('T')[0]}.csv"`,
    },
  })
}
```

## CSV Generator Utility

```typescript
// lib/csv.ts
interface CSVColumn<T> {
  key: keyof T
  label: string
  format?: (value: unknown) => string
}

export function generateCSV<T extends Record<string, unknown>>(
  rows: T[],
  columns: CSVColumn<T>[]
): string {
  const escape = (value: unknown): string => {
    const str = String(value ?? '')
    // Escape values containing commas, quotes, or newlines
    if (str.includes(',') || str.includes('"') || str.includes('\n')) {
      return `"${str.replace(/"/g, '""')}"`
    }
    return str
  }

  const header = columns.map(col => escape(col.label)).join(',')
  
  const dataRows = rows.map(row =>
    columns.map(col => {
      const value = row[col.key]
      const formatted = col.format ? col.format(value) : value
      return escape(formatted)
    }).join(',')
  )

  return [header, ...dataRows].join('\n')
}
```

## Download Trigger in React

```typescript
'use client'

export function ExportButton() {
  async function handleExport() {
    const response = await fetch('/api/admin/export/invoices')
    if (!response.ok) return alert('Export failed')
    
    const blob = await response.blob()
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = response.headers.get('content-disposition')?.match(/filename="(.+)"/)?.[1] ?? 'export.csv'
    a.click()
    URL.revokeObjectURL(url)
  }

  return <button onClick={handleExport}>Export CSV</button>
}
```

## Large Dataset Streaming

For exports with 10,000+ rows, stream the response instead of buffering:

```typescript
export async function GET(req: NextRequest) {
  const supabase = createAdminClient()
  
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder()
      
      // Write header
      controller.enqueue(encoder.encode('Invoice #,Customer,Amount,Status\n'))
      
      // Paginate through data
      let offset = 0
      const pageSize = 1000
      
      while (true) {
        const { data } = await supabase
          .from('invoices')
          .select('number, customer_name, total, status')
          .range(offset, offset + pageSize - 1)
        
        if (!data || data.length === 0) break
        
        const rows = data.map(inv =>
          `${inv.number},${inv.customer_name},$${inv.total.toFixed(2)},${inv.status}`
        ).join('\n') + '\n'
        
        controller.enqueue(encoder.encode(rows))
        
        if (data.length < pageSize) break
        offset += pageSize
      }
      
      controller.close()
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': 'attachment; filename="invoices.csv"',
    },
  })
}
```

## Security Considerations

- Always require auth on export endpoints
- Never export sensitive fields (passwords, session tokens, full payment info)
- Consider rate limiting exports (one per minute per user) to prevent data scraping
- For admin exports, log the export event (who exported what, when)
