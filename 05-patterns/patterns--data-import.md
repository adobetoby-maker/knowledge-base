# Pattern: Data Import (CSV / Excel)

## What This Solves

Importing existing data from CSV or Excel is a common onboarding task — importing a customer list, historical invoices, or product catalog. The pattern: parse in a Server Action, validate each row with Zod, report per-row errors without aborting the whole import.

## CSV Upload + Parse

```tsx
// app/admin/import/page.tsx
'use client'
import { useRef, useState } from 'react'
import { importClients } from './actions'

interface ImportResult {
  success: number
  failed: Array<{ row: number; error: string; data: Record<string, unknown> }>
}

export default function ImportPage() {
  const [result, setResult] = useState<ImportResult | null>(null)
  const [loading, setLoading] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  const handleImport = async () => {
    const file = fileRef.current?.files?.[0]
    if (!file) return

    setLoading(true)
    try {
      const text = await file.text()
      const formData = new FormData()
      formData.append('csv', text)
      const result = await importClients(formData)
      setResult(result)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="space-y-4">
      <input ref={fileRef} type="file" accept=".csv,.xlsx" />
      <Button onClick={handleImport} disabled={loading}>
        {loading ? 'Importing...' : 'Import'}
      </Button>

      {result && (
        <div>
          <p className="text-green-600">{result.success} rows imported successfully</p>
          {result.failed.length > 0 && (
            <div>
              <p className="text-destructive">{result.failed.length} rows failed:</p>
              <ul className="text-sm space-y-1">
                {result.failed.map(f => (
                  <li key={f.row}>Row {f.row}: {f.error}</li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
```

## Server Action: CSV Parse and Validate

```ts
// app/admin/import/actions.ts
'use server'
import { z } from 'zod'
import { parse } from 'csv-parse/sync'
import { supabaseAdmin } from '@/lib/supabase/admin'
import { validateAdminSession } from '@/lib/adminAuth'
import { cookies } from 'next/headers'

const ClientRowSchema = z.object({
  name: z.string().min(1, 'Name is required').max(200),
  email: z.string().email('Invalid email').optional().or(z.literal('')),
  phone: z.string().optional(),
  notes: z.string().optional(),
})

export async function importClients(formData: FormData) {
  // Auth check first
  const cookieStore = await cookies()
  const session = await validateAdminSession(
    new Request('http://localhost', { headers: { cookie: cookieStore.toString() } }) as NextRequest
  )
  if (!session) throw new Error('Unauthorized')

  const csvText = formData.get('csv') as string

  // Parse CSV
  const rows = parse(csvText, {
    columns: true,        // Use first row as column names
    skip_empty_lines: true,
    trim: true,
  })

  const success: Array<typeof ClientRowSchema._type> = []
  const failed: Array<{ row: number; error: string; data: unknown }> = []

  for (const [i, row] of rows.entries()) {
    const rowNum = i + 2  // 1-indexed, +1 for header row

    const result = ClientRowSchema.safeParse(row)
    if (!result.success) {
      failed.push({
        row: rowNum,
        error: result.error.errors.map(e => `${e.path.join('.')}: ${e.message}`).join(', '),
        data: row,
      })
      continue
    }

    success.push(result.data)
  }

  // Batch insert valid rows
  if (success.length > 0) {
    const { error } = await supabaseAdmin
      .from('clients')
      .insert(success.map(row => ({
        name: row.name,
        email: row.email || null,
        phone: row.phone || null,
        notes: row.notes || null,
      })))

    if (error) throw new Error(`Database error: ${error.message}`)
  }

  return { success: success.length, failed }
}
```

## Excel Support (.xlsx)

```ts
// For .xlsx files, use 'xlsx' package
import * as XLSX from 'xlsx'

async function parseExcel(buffer: ArrayBuffer): Promise<Record<string, unknown>[]> {
  const wb = XLSX.read(buffer, { type: 'array' })
  const ws = wb.Sheets[wb.SheetNames[0]]  // First sheet
  return XLSX.utils.sheet_to_json(ws, { defval: '' })  // Empty cells → empty string
}
```

In the action, detect the file type:
```ts
const isExcel = filename.endsWith('.xlsx') || filename.endsWith('.xls')
const rows = isExcel
  ? await parseExcel(await file.arrayBuffer())
  : parse(await file.text(), { columns: true, trim: true })
```

## Template Download

Always provide a template CSV for users to fill in:

```ts
// Route Handler: GET /api/import/template
export async function GET() {
  const headers = ['name', 'email', 'phone', 'notes']
  const example = ['Acme Corp', 'contact@acme.com', '(208) 555-1234', 'Priority client']
  const csv = [headers.join(','), example.join(',')].join('\n')

  return new NextResponse(csv, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': 'attachment; filename="import-template.csv"',
    },
  })
}
```

## Common Import Issues

- **BOM characters**: Excel-exported UTF-8 CSVs often start with a BOM (`﻿`). Strip it: `csvText.replace(/^﻿/, '')`
- **Column name variations**: Users rename columns. Normalize before parsing: `{ name: row.Name ?? row.name ?? row['Client Name'] ?? '' }`
- **Date formats**: Use `z.coerce.date()` or accept strings and parse manually — users use many date formats
- **Empty trailing rows**: `skip_empty_lines: true` in csv-parse handles this
