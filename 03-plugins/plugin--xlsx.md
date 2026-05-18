# Plugin: XLSX (SheetJS)

## Overview

SheetJS (`xlsx`) reads and writes Excel files (.xlsx, .xls, .csv, .ods) in Node.js and browsers. Use it for: exporting data tables to Excel, parsing uploaded spreadsheets, generating formatted reports.

## Install

```bash
npm install xlsx
```

## Read Excel File (Node.js)

```ts
import * as XLSX from 'xlsx'

const workbook = XLSX.readFile('./data.xlsx')

// Get first sheet
const sheetName = workbook.SheetNames[0]
const sheet = workbook.Sheets[sheetName]

// Convert to array of objects (header row becomes keys)
const data = XLSX.utils.sheet_to_json(sheet)
// [{ Name: 'Jane', Email: 'jane@...', Amount: 1500 }, ...]

// Raw array of arrays (including header row)
const rows = XLSX.utils.sheet_to_json(sheet, { header: 1 })
// [['Name', 'Email', 'Amount'], ['Jane', 'jane@...', 1500], ...]
```

## Read Uploaded File (Browser)

```ts
import * as XLSX from 'xlsx'

async function parseUploadedExcel(file: File) {
  const buffer = await file.arrayBuffer()
  const workbook = XLSX.read(buffer, { type: 'array' })
  
  const sheetName = workbook.SheetNames[0]
  const sheet = workbook.Sheets[sheetName]
  
  return XLSX.utils.sheet_to_json<Record<string, unknown>>(sheet)
}
```

## Write Excel File (Node.js)

```ts
import * as XLSX from 'xlsx'

const data = [
  { Name: 'Jane Doe', Email: 'jane@example.com', Amount: 1500.00 },
  { Name: 'John Smith', Email: 'john@example.com', Amount: 2750.00 },
]

// Create worksheet from data
const sheet = XLSX.utils.json_to_sheet(data)

// Create workbook and append sheet
const workbook = XLSX.utils.book_new()
XLSX.utils.book_append_sheet(workbook, sheet, 'Invoices')

// Write to file
XLSX.writeFile(workbook, './invoices.xlsx')
```

## Download Excel (Browser)

```ts
function downloadExcel(data: object[], filename: string) {
  const sheet = XLSX.utils.json_to_sheet(data)
  const workbook = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(workbook, sheet, 'Sheet1')
  
  // Generate blob and download
  const buffer = XLSX.write(workbook, { type: 'array', bookType: 'xlsx' })
  const blob = new Blob([buffer], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  })
  
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename.endsWith('.xlsx') ? filename : `${filename}.xlsx`
  a.click()
  URL.revokeObjectURL(url)
}
```

## Column Width and Formatting

```ts
// Set column widths
sheet['!cols'] = [
  { wch: 20 },   // Column A: 20 characters wide
  { wch: 30 },   // Column B: 30 characters wide
  { wch: 12 },   // Column C: 12 characters wide
]

// Freeze first row (headers stay visible when scrolling)
sheet['!freeze'] = { xSplit: 0, ySplit: 1 }
```

## Multiple Sheets

```ts
const workbook = XLSX.utils.book_new()

XLSX.utils.book_append_sheet(workbook, 
  XLSX.utils.json_to_sheet(invoicesData), 
  'Invoices'
)

XLSX.utils.book_append_sheet(workbook,
  XLSX.utils.json_to_sheet(paymentsData),
  'Payments'
)

XLSX.utils.book_append_sheet(workbook,
  XLSX.utils.json_to_sheet(summaryData),
  'Summary'
)

XLSX.writeFile(workbook, './report.xlsx')
```

## Date Handling

Excel stores dates as serial numbers. SheetJS converts them but can lose time:

```ts
// Read dates correctly
const data = XLSX.utils.sheet_to_json(sheet, {
  raw: false,  // Convert dates to strings (prevents number format)
})

// Or handle manually
const data = XLSX.utils.sheet_to_json(sheet, { raw: true })
// Date cells come as numbers — convert:
const dateSerial = 45895  // Excel serial
const date = new Date(Date.UTC(1899, 11, 30) + dateSerial * 86400000)
```

For clean date handling, pass `raw: false` and let SheetJS format as strings, then parse with dayjs or date-fns.

## Cell Type Coercion Issues

Excel often stores numbers as text:
- Zip codes: `"94103"` — stays string if stored as text in Excel
- Phone numbers: stored as text (good)
- Currency: may have `$` symbols or commas: `"$1,500.00"` — parse manually

After `sheet_to_json`, validate and coerce types before using data:
```ts
const rows = rawData.map(row => ({
  ...row,
  amount: parseFloat(String(row.Amount).replace(/[$,]/g, '')),
  zipCode: String(row.ZipCode).padStart(5, '0'),
}))
```

## XLSX vs PapaParse

| | XLSX | PapaParse |
|--|------|---------|
| CSV | Yes | Yes (specialized) |
| .xlsx | Yes | No |
| .xls (old Excel) | Yes | No |
| Streaming | Limited | Yes |
| Bundle size | ~800KB | ~50KB |

Use XLSX when Excel support is required. Use PapaParse for CSV-only workflows.
