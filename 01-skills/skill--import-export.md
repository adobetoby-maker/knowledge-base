# Skill: Import / Export (CSV/Excel)

## Overview

Import and export are common data management features. Export: fetch data, format as CSV/Excel, stream to browser. Import: parse uploaded file, validate rows, insert with error reporting. The key challenge with import: handling partial failures gracefully — don't reject the whole file because 2 out of 500 rows have bad data.

## CSV Export

```ts
function objectsToCSV(rows: Record<string, unknown>[], columns: { key: string; label: string }[]): string {
  const headers = columns.map(c => JSON.stringify(c.label)).join(',')
  const body = rows.map(row =>
    columns.map(c => {
      const val = row[c.key]
      if (val === null || val === undefined) return ''
      if (typeof val === 'string') return JSON.stringify(val)  // Escape commas, quotes
      return String(val)
    }).join(',')
  ).join('\n')
  return `${headers}\n${body}`
}

// Route handler
export async function GET(req: Request) {
  const { userId } = await getSession()
  const contacts = await db.select().from(contacts).where(eq(contacts.userId, userId))

  const csv = objectsToCSV(contacts, [
    { key: 'name', label: 'Name' },
    { key: 'email', label: 'Email' },
    { key: 'phone', label: 'Phone' },
    { key: 'createdAt', label: 'Created At' },
  ])

  return new Response(csv, {
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': `attachment; filename="contacts-${Date.now()}.csv"`,
    },
  })
}
```

## Excel Export with ExcelJS

```ts
import ExcelJS from 'exceljs'

async function generateExcel(data: Contact[]): Promise<Buffer> {
  const workbook = new ExcelJS.Workbook()
  const sheet = workbook.addWorksheet('Contacts')

  // Headers with styling
  sheet.columns = [
    { header: 'Name', key: 'name', width: 20 },
    { header: 'Email', key: 'email', width: 30 },
    { header: 'Phone', key: 'phone', width: 15 },
    { header: 'Created', key: 'createdAt', width: 20 },
  ]

  // Bold headers
  sheet.getRow(1).font = { bold: true }
  sheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE5E7EB' } }

  // Add data
  data.forEach(row => sheet.addRow({
    name: row.name,
    email: row.email,
    phone: row.phone,
    createdAt: row.createdAt.toLocaleDateString(),
  }))

  return workbook.xlsx.writeBuffer() as Promise<Buffer>
}
```

## CSV Import with Validation

```ts
import { parse } from 'csv-parse/sync'
import { z } from 'zod'

const ContactRowSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  email: z.string().email('Invalid email'),
  phone: z.string().optional(),
})

interface ImportResult {
  success: number
  errors: { row: number; errors: string[] }[]
}

async function importCSV(csvContent: string, userId: string): Promise<ImportResult> {
  const rows = parse(csvContent, {
    columns: true,      // Use first row as headers
    skip_empty_lines: true,
    trim: true,
  })

  const result: ImportResult = { success: 0, errors: [] }
  const validRows: z.infer<typeof ContactRowSchema>[] = []

  // Validate all rows first
  rows.forEach((row: Record<string, string>, index: number) => {
    const parsed = ContactRowSchema.safeParse(row)
    if (!parsed.success) {
      result.errors.push({
        row: index + 2,  // +1 for header, +1 for 1-indexed
        errors: parsed.error.issues.map(i => `${i.path.join('.')}: ${i.message}`),
      })
    } else {
      validRows.push(parsed.data)
    }
  })

  // Insert valid rows in batches
  if (validRows.length > 0) {
    await db.insert(contacts).values(
      validRows.map(row => ({ ...row, userId }))
    ).onConflictDoUpdate({
      target: [contacts.email, contacts.userId],
      set: { name: sql`excluded.name`, phone: sql`excluded.phone` },
    })
    result.success = validRows.length
  }

  return result
}
```

## Import UI with Progress

```tsx
function ImportModal({ onClose }: { onClose: () => void }) {
  const [status, setStatus] = useState<'idle' | 'processing' | 'done'>('idle')
  const [result, setResult] = useState<ImportResult | null>(null)

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return

    setStatus('processing')
    const text = await file.text()

    const res = await fetch('/api/contacts/import', {
      method: 'POST',
      body: text,
      headers: { 'Content-Type': 'text/csv' },
    })

    const data = await res.json()
    setResult(data)
    setStatus('done')
  }

  return (
    <div className="p-6">
      {status === 'idle' && (
        <>
          <p className="text-sm text-gray-600 mb-4">Upload a CSV with columns: Name, Email, Phone</p>
          <input type="file" accept=".csv" onChange={handleFile} className="block" />
          <a href="/api/contacts/import-template" className="text-sm text-blue-600 mt-2 block">
            Download template
          </a>
        </>
      )}
      {status === 'processing' && <p>Processing...</p>}
      {status === 'done' && result && (
        <div className="space-y-3">
          <p className="text-green-600 text-sm">{result.success} contacts imported</p>
          {result.errors.length > 0 && (
            <div>
              <p className="text-red-600 text-sm mb-2">{result.errors.length} rows failed:</p>
              <ul className="text-xs space-y-1 max-h-48 overflow-y-auto">
                {result.errors.map(e => (
                  <li key={e.row} className="text-red-600">Row {e.row}: {e.errors.join(', ')}</li>
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

## Key Rules

- Always validate all rows before inserting — report errors per-row, not a single failure that aborts everything.
- Insert valid rows even when some rows fail — a "50% success" import is better than a 100% failure.
- Use `ON CONFLICT DO UPDATE` for imports — re-importing the same file should be idempotent, not error on duplicates.
- Include a "Download template" link in the import UI — users need the exact column format to avoid validation errors.
- Large imports (10,000+ rows) should be handled as a background job with a progress indicator, not a synchronous API call.
