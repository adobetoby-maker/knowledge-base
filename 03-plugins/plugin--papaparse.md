# Plugin: PapaParse

## Overview

PapaParse is the de-facto standard for CSV parsing in JavaScript. Handles: malformed CSV, quoted fields with commas/newlines, streaming large files, worker-based background parsing, and CSV generation.

## Install

```bash
npm install papaparse
npm install --save-dev @types/papaparse
```

## Basic Parsing

```ts
import Papa from 'papaparse'

// String input
const result = Papa.parse('name,age\nJane,30\nJohn,25', {
  header: true,     // Use first row as field names
  dynamicTyping: true, // Auto-convert "30" → 30, "true" → true
})

result.data    // [{ name: 'Jane', age: 30 }, { name: 'John', age: 25 }]
result.errors  // [] (empty = success)
result.meta    // { fields: ['name', 'age'], delimiter: ',', linebreak: '\n' }
```

## File Input (Browser)

```ts
// Parse File object from <input type="file">
Papa.parse(file, {
  header: true,
  dynamicTyping: true,
  skipEmptyLines: true,
  complete: (results) => {
    console.log(results.data)
  },
  error: (error) => {
    console.error('Parse error:', error.message)
  },
})
```

Always use `skipEmptyLines: true` for user-uploaded files — trailing newlines create empty rows.

## Streaming Large Files

For files over ~10MB, stream to avoid blocking the main thread:

```ts
Papa.parse(file, {
  header: true,
  dynamicTyping: true,
  skipEmptyLines: true,
  chunk: (results, parser) => {
    // Process results.data (array of rows in this chunk)
    processChunk(results.data)
    
    // Pause parsing (if you need to wait for async work)
    // parser.pause()
    // ... then later: parser.resume()
  },
  complete: () => {
    console.log('Done')
  },
})
```

## Worker-Based Parsing (Non-blocking)

```ts
Papa.parse(file, {
  worker: true,    // Parse in Web Worker
  header: true,
  complete: (results) => {
    setData(results.data)
  },
})
```

`worker: true` is for large files in browser. Not available in Node.js.

## Node.js File Streaming

```ts
import { createReadStream } from 'fs'
import Papa from 'papaparse'

const stream = createReadStream('./data.csv')

Papa.parse(stream, {
  header: true,
  dynamicTyping: true,
  step: (row) => {
    processRow(row.data)  // Called once per row
  },
  complete: () => {
    console.log('Finished')
  },
})
```

`step` (row-by-row) vs `chunk` (batched rows) — use `step` when each row is processed independently; use `chunk` when batching is more efficient for your processing logic.

## Type Coercion

`dynamicTyping: true` handles common conversions but watch for edge cases:

```ts
// These are converted:
"42"     → 42
"3.14"   → 3.14
"true"   → true
"false"  → false
"null"   → null
""       → ""  // NOT null — empty string stays empty string

// Watch out:
"01234"  → 1234  // Leading zeros stripped (phone numbers, zip codes!)
```

For IDs, zip codes, or phone numbers: use `dynamicTyping: false` and manually parse numbers where needed.

## Error Handling

```ts
Papa.parse(file, {
  header: true,
  complete: (results) => {
    if (results.errors.length > 0) {
      // Row-level errors (parse failures)
      const errors = results.errors.map(e =>
        `Row ${e.row}: ${e.message} (${e.type})`
      )
      // Still have results.data — parsing continues after errors
    }
  },
})
```

PapaParse continues parsing after row errors. `results.data` contains successfully parsed rows. Check `results.errors` after parsing, not instead of using `results.data`.

## CSV Generation (Unparse)

```ts
const data = [
  { name: 'Jane Doe', email: 'jane@example.com', amount: 1500 },
  { name: 'John Smith', email: 'john@example.com', amount: 2750 },
]

const csv = Papa.unparse(data)
// "name,email,amount\nJane Doe,jane@example.com,1500\n..."

// Download in browser
const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
const url = URL.createObjectURL(blob)
const a = document.createElement('a')
a.href = url
a.download = 'export.csv'
a.click()
URL.revokeObjectURL(url)
```

## Custom Delimiters

```ts
// Tab-separated (TSV)
Papa.parse(data, { delimiter: '\t' })

// Semicolons (common in European Excel exports)
Papa.parse(data, { delimiter: ';' })

// Auto-detect
Papa.parse(data, { delimiter: '' })  // Empty = auto-detect
```

## Encoding

```ts
Papa.parse(file, {
  encoding: 'UTF-8',  // Default
})

// For Windows-1252 (common in older Excel exports)
Papa.parse(file, {
  encoding: 'windows-1252',
})
```

When users upload CSV exports from Excel, encoding issues with special characters (é, ü, ñ) are the most common complaint. Test with non-ASCII names.
