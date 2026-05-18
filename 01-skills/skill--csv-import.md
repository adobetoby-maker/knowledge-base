# CSV Import

## The Pattern

CSV import is a common admin feature for bulk data entry. The flow:
1. User uploads CSV file
2. Parse CSV → validate rows → show preview with errors
3. User confirms → import valid rows to DB

## File Upload Component

```typescript
// components/CsvUploader.tsx
'use client'
import { useState } from 'react'
import { useDropzone } from 'react-dropzone'
import Papa from 'papaparse'

interface ParsedRow {
  data: Record<string, string>
  errors: string[]
}

interface UploadState {
  rows: ParsedRow[]
  validCount: number
  errorCount: number
}

export function CsvUploader({ onParsed }: { onParsed: (state: UploadState) => void }) {
  const [fileName, setFileName] = useState('')
  
  const { getRootProps, getInputProps } = useDropzone({
    accept: { 'text/csv': ['.csv'] },
    maxFiles: 1,
    onDrop: (files) => {
      const file = files[0]
      if (!file) return
      
      setFileName(file.name)
      
      Papa.parse(file, {
        header: true,
        skipEmptyLines: true,
        complete: (results) => {
          const rows = results.data.map((row) => validateRow(row as Record<string, string>))
          onParsed({
            rows,
            validCount: rows.filter(r => r.errors.length === 0).length,
            errorCount: rows.filter(r => r.errors.length > 0).length,
          })
        },
      })
    },
  })
  
  return (
    <div
      {...getRootProps()}
      className="border-2 border-dashed rounded-lg p-8 text-center cursor-pointer hover:border-primary transition-colors"
    >
      <input {...getInputProps()} />
      {fileName ? (
        <p className="text-sm font-medium">{fileName}</p>
      ) : (
        <>
          <p className="font-medium">Drop CSV file here</p>
          <p className="text-sm text-muted-foreground mt-1">or click to browse</p>
        </>
      )}
    </div>
  )
}
```

## Row Validation

```typescript
// lib/csv-validators.ts
import { z } from 'zod'

const CustomerRowSchema = z.object({
  name: z.string().min(1, 'Name required'),
  email: z.string().email('Invalid email'),
  phone: z.string().optional(),
})

function validateRow(row: Record<string, string>): ParsedRow {
  const result = CustomerRowSchema.safeParse({
    name: row['Name'] ?? row['name'],
    email: row['Email'] ?? row['email'],
    phone: row['Phone'] ?? row['phone'],
  })
  
  if (result.success) {
    return { data: row, errors: [] }
  }
  
  return {
    data: row,
    errors: result.error.issues.map(i => i.message),
  }
}
```

## Preview Before Import

Show the user what will be imported and flag errors:

```typescript
function ImportPreview({ state, onImport }: { state: UploadState; onImport: () => void }) {
  return (
    <div className="space-y-4">
      <div className="flex gap-4 text-sm">
        <span className="text-green-600 font-medium">{state.validCount} rows ready to import</span>
        {state.errorCount > 0 && (
          <span className="text-destructive font-medium">{state.errorCount} rows have errors</span>
        )}
      </div>
      
      <div className="max-h-64 overflow-y-auto rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Status</TableHead>
              <TableHead>Name</TableHead>
              <TableHead>Email</TableHead>
              <TableHead>Error</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {state.rows.map((row, i) => (
              <TableRow key={i} className={row.errors.length > 0 ? 'bg-destructive/5' : ''}>
                <TableCell>
                  {row.errors.length === 0
                    ? <Check className="h-4 w-4 text-green-500" />
                    : <X className="h-4 w-4 text-destructive" />
                  }
                </TableCell>
                <TableCell>{row.data.name}</TableCell>
                <TableCell>{row.data.email}</TableCell>
                <TableCell className="text-destructive text-xs">{row.errors.join(', ')}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
      
      <Button
        onClick={onImport}
        disabled={state.validCount === 0}
      >
        Import {state.validCount} customers
      </Button>
    </div>
  )
}
```

## Server Action for Import

```typescript
// lib/actions/import-customers.ts
'use server'
import { createAdminClient } from '@/lib/supabase/admin'
import { validateAdminSession } from '@/lib/adminAuth'

export async function importCustomers(rows: CustomerRow[]) {
  await validateAdminSession()
  
  const supabase = createAdminClient()
  
  // Batch insert — upsert on email to handle duplicates:
  const { data, error } = await supabase
    .from('customers')
    .upsert(
      rows.map(row => ({
        name: row.name,
        email: row.email,
        phone: row.phone,
        created_at: new Date().toISOString(),
      })),
      { onConflict: 'email' }
    )
    .select()
  
  if (error) {
    console.error('Import failed:', error)
    return { success: false, error: 'Import failed — check for duplicates or invalid data' }
  }
  
  return { success: true, imported: data?.length ?? 0 }
}
```

## CSV Template Download

Provide a template so users know the expected format:

```typescript
function downloadTemplate() {
  const csvContent = [
    'Name,Email,Phone',  // header row
    'John Smith,john@example.com,(208) 555-0100',  // example row
  ].join('\n')
  
  const blob = new Blob([csvContent], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'customer-import-template.csv'
  a.click()
  URL.revokeObjectURL(url)
}
```
