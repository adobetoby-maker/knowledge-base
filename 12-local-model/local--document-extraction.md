# Local Model: Document Extraction

## Overview

Extract structured data from unstructured documents (invoices, contracts, forms, reports) using local models. Particularly valuable when documents contain PII or confidential business data that shouldn't leave your infrastructure.

## Use Cases

- Invoice data extraction (vendor, amount, line items, due date)
- Contract clause extraction (payment terms, termination clauses, dates)
- Medical record summarization (requires local — never cloud)
- Job application parsing (name, skills, experience)
- Form digitization (handwritten or scanned forms → structured data)

## Prompt Engineering for Extraction

Structure matters more than length for extraction tasks. Give the model an exact output template:

```ts
function buildExtractionPrompt(documentText: string, schema: ExtractionSchema): string {
  const fieldDescriptions = Object.entries(schema.fields)
    .map(([key, def]) => `- ${key} (${def.type}${def.required ? ', required' : ', optional'}): ${def.description}`)
    .join('\n')

  return `Extract the following information from this document. Return ONLY valid JSON, no explanation.

Required fields:
${fieldDescriptions}

Document:
${documentText}

Return JSON matching exactly this structure:
${JSON.stringify(schema.example, null, 2)}

If a field cannot be found, use null for optional fields.
For required fields not found, use an empty string "".`
}
```

## Invoice Extraction Example

```ts
const INVOICE_SCHEMA = {
  fields: {
    vendor_name: { type: 'string', required: true, description: 'Company or person who issued the invoice' },
    invoice_number: { type: 'string', required: true, description: 'Invoice ID or number' },
    invoice_date: { type: 'string', required: true, description: 'Date in YYYY-MM-DD format' },
    due_date: { type: 'string', required: false, description: 'Payment due date in YYYY-MM-DD format' },
    total_amount: { type: 'number', required: true, description: 'Total amount in dollars (not cents)' },
    currency: { type: 'string', required: false, description: 'Currency code e.g. USD, EUR' },
    line_items: {
      type: 'array',
      required: false,
      description: 'Array of line items with description, quantity, unit_price',
    },
  },
  example: {
    vendor_name: 'Acme Corp',
    invoice_number: 'INV-12345',
    invoice_date: '2026-05-18',
    due_date: '2026-06-18',
    total_amount: 1500.00,
    currency: 'USD',
    line_items: [
      { description: 'Web Development', quantity: 10, unit_price: 150.00 },
    ],
  },
}

async function extractInvoiceData(pdfText: string): Promise<InvoiceData> {
  const prompt = buildExtractionPrompt(pdfText, INVOICE_SCHEMA)

  const response = await callOllama({
    model: 'llama3.2:8b',
    prompt,
    options: {
      temperature: 0,      // Low temperature — extraction is deterministic
      num_predict: 1024,   // Enough for a full invoice JSON
    },
  })

  // Parse JSON — handle model sometimes adding markdown fences
  const jsonMatch = response.match(/```json\s*([\s\S]*?)```/) ?? response.match(/(\{[\s\S]*\})/)
  const json = jsonMatch?.[1] ?? response.trim()

  try {
    const data = JSON.parse(json) as InvoiceData
    return validateInvoiceData(data)  // Validate required fields
  } catch {
    throw new Error(`Extraction failed: model returned non-JSON: ${json.slice(0, 200)}`)
  }
}
```

## Multi-Pass Extraction for Long Documents

Local models have smaller context windows (8k–32k tokens). For long documents, chunk and extract in passes:

```ts
async function extractFromLongDocument(text: string, schema: ExtractionSchema): Promise<ExtractResult> {
  const MAX_CHUNK_CHARS = 6000  // ~1500 tokens
  const chunks = chunkText(text, MAX_CHUNK_CHARS)

  // Pass 1: extract from each chunk
  const chunkResults = await Promise.all(
    chunks.map((chunk) => extractFromChunk(chunk, schema))
  )

  // Pass 2: merge conflicting extractions
  if (chunkResults.length === 1) return chunkResults[0]

  const mergePrompt = `
You extracted the following data from different sections of the same document.
Merge them into a single accurate record. Resolve conflicts by taking the most specific/complete value.

${chunkResults.map((r, i) => `Section ${i + 1}:\n${JSON.stringify(r, null, 2)}`).join('\n\n')}

Return merged JSON only.
`
  const merged = await callOllama({ model: 'llama3.2:8b', prompt: mergePrompt, options: { temperature: 0 } })
  return JSON.parse(merged.match(/(\{[\s\S]*\})/)?.[1] ?? '{}')
}

function chunkText(text: string, maxChars: number): string[] {
  if (text.length <= maxChars) return [text]

  const chunks: string[] = []
  let i = 0
  while (i < text.length) {
    // Break at paragraph boundary if possible
    const end = Math.min(i + maxChars, text.length)
    const breakPoint = text.lastIndexOf('\n', end)
    const chunkEnd = breakPoint > i ? breakPoint : end
    chunks.push(text.slice(i, chunkEnd))
    i = chunkEnd
  }
  return chunks
}
```

## Validation Layer

Always validate extracted data before storing:

```ts
import { z } from 'zod'

const InvoiceSchema = z.object({
  vendor_name: z.string().min(1),
  invoice_number: z.string().min(1),
  invoice_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  due_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional().nullable(),
  total_amount: z.number().positive(),
  currency: z.string().length(3).optional().nullable(),
  line_items: z.array(z.object({
    description: z.string(),
    quantity: z.number(),
    unit_price: z.number(),
  })).optional(),
})

function validateInvoiceData(data: unknown): InvoiceData {
  const result = InvoiceSchema.safeParse(data)
  if (!result.success) {
    throw new Error(`Validation failed: ${result.error.message}`)
  }
  return result.data
}
```

## Quality Metrics

Track extraction accuracy over time:

```ts
await supabase.from('extraction_log').insert({
  document_id: doc.id,
  model: 'llama3.2:8b',
  fields_extracted: Object.keys(result).length,
  fields_empty: Object.values(result).filter(v => !v).length,
  validation_passed: true,
  extraction_time_ms: elapsed,
})
```

If empty fields exceed 30% consistently for a document type, the prompt needs tuning for that format.
