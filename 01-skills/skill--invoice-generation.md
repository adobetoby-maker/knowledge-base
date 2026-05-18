# Skill: Invoice Generation

## Architecture Choice

Two strategies: **server-rendered HTML to PDF** (via Playwright/Puppeteer or `@react-pdf/renderer`) or **static PDF from template** (via `pdf-lib`). For invoice PDFs with rich formatting, server-rendered HTML is more maintainable.

## Strategy 1: Playwright HTML-to-PDF (Recommended)

Best for: pixel-perfect branding, complex layouts, print-ready.

```ts
// lib/pdf/invoice-pdf.ts
import playwright from 'playwright'
import { renderInvoiceHtml } from './invoice-html'

export async function generateInvoicePdf(invoiceId: string): Promise<Buffer> {
  const invoice = await fetchInvoiceData(invoiceId)
  const html = renderInvoiceHtml(invoice)

  const browser = await playwright.chromium.launch({ headless: true })
  const page = await browser.newPage()

  await page.setContent(html, { waitUntil: 'networkidle' })

  const pdf = await page.pdf({
    format: 'Letter',
    printBackground: true,
    margin: { top: '0.5in', bottom: '0.5in', left: '0.5in', right: '0.5in' },
  })

  await browser.close()
  return Buffer.from(pdf)
}
```

Playwright isn't available on Vercel Edge — run this in a Node.js Route Handler or Supabase Edge Function.

## Invoice HTML Template

```ts
// lib/pdf/invoice-html.ts
import type { Invoice, Client, LineItem } from '@/types'
import { format } from 'date-fns'

interface InvoiceData {
  invoice: Invoice & { line_items: LineItem[]; client: Client }
}

export function renderInvoiceHtml({ invoice }: InvoiceData): string {
  const totalCents = invoice.line_items.reduce(
    (sum, item) => sum + item.unit_price_cents * item.quantity,
    0
  )
  const total = (totalCents / 100).toFixed(2)

  const itemRows = invoice.line_items
    .map(
      (item) => `
      <tr>
        <td>${item.description}</td>
        <td style="text-align:right">${item.quantity}</td>
        <td style="text-align:right">$${(item.unit_price_cents / 100).toFixed(2)}</td>
        <td style="text-align:right">$${((item.unit_price_cents * item.quantity) / 100).toFixed(2)}</td>
      </tr>`
    )
    .join('')

  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body { font-family: -apple-system, sans-serif; color: #1a1a1a; margin: 0; }
  .header { display: flex; justify-content: space-between; margin-bottom: 32px; }
  .logo { font-size: 24px; font-weight: 700; color: #1e40af; }
  .invoice-meta { text-align: right; }
  .invoice-number { font-size: 28px; font-weight: 700; }
  table { width: 100%; border-collapse: collapse; margin-top: 24px; }
  th { background: #f3f4f6; padding: 10px; text-align: left; }
  td { padding: 10px; border-bottom: 1px solid #e5e7eb; }
  .total-row { font-weight: 700; font-size: 16px; background: #f3f4f6; }
</style>
</head>
<body>
  <div class="header">
    <div>
      <div class="logo">JR's Auto Repair</div>
      <div>417 Main Ave E, Twin Falls, ID 83301</div>
      <div>(208) 595-2101</div>
    </div>
    <div class="invoice-meta">
      <div class="invoice-number">Invoice #${invoice.number}</div>
      <div>Date: ${format(new Date(invoice.created_at), 'MMMM d, yyyy')}</div>
      <div>Due: ${format(new Date(invoice.due_date), 'MMMM d, yyyy')}</div>
    </div>
  </div>

  <div><strong>Bill To:</strong></div>
  <div>${invoice.client.name}</div>
  <div>${invoice.client.email}</div>

  <table>
    <thead>
      <tr><th>Description</th><th style="text-align:right">Qty</th><th style="text-align:right">Price</th><th style="text-align:right">Total</th></tr>
    </thead>
    <tbody>${itemRows}</tbody>
    <tfoot>
      <tr class="total-row">
        <td colspan="3" style="text-align:right">Total</td>
        <td style="text-align:right">$${total}</td>
      </tr>
    </tfoot>
  </table>
</body>
</html>`
}
```

## Route Handler: Generate and Serve PDF

```ts
// app/api/invoices/[id]/pdf/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { generateInvoicePdf } from '@/lib/pdf/invoice-pdf'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params

  // Auth: allow admin or token-authenticated access
  const token = request.nextUrl.searchParams.get('token')
  const isValid = await validateInvoiceAccess(id, token)
  if (!isValid) return new NextResponse('Unauthorized', { status: 401 })

  const pdf = await generateInvoicePdf(id)

  return new NextResponse(pdf, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="invoice-${id}.pdf"`,
      'Cache-Control': 'private, max-age=300',  // Cache 5 min
    },
  })
}
```

## Strategy 2: @react-pdf/renderer

```bash
npm install @react-pdf/renderer
```

```tsx
// emails/InvoicePDF.tsx
import { Document, Page, Text, View, StyleSheet } from '@react-pdf/renderer'

const styles = StyleSheet.create({
  page: { padding: 40, fontFamily: 'Helvetica' },
  header: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 20 },
  title: { fontSize: 24, fontWeight: 'bold' },
  table: { marginTop: 20 },
  row: { flexDirection: 'row', borderBottomWidth: 1, borderColor: '#e5e7eb', paddingVertical: 8 },
})

export function InvoicePDF({ invoice }: { invoice: InvoiceData }) {
  return (
    <Document>
      <Page size="LETTER" style={styles.page}>
        <View style={styles.header}>
          <Text style={styles.title}>Invoice #{invoice.number}</Text>
        </View>
        {/* ... line items ... */}
      </Page>
    </Document>
  )
}

// Generate
import { renderToBuffer } from '@react-pdf/renderer'
const buffer = await renderToBuffer(<InvoicePDF invoice={invoice} />)
```

`@react-pdf/renderer` runs entirely in Node.js (no headless browser). Faster and lighter than Playwright. Tradeoff: subset of CSS supported; complex layouts harder. Use for simpler, data-heavy documents.

## Storing PDFs in Supabase Storage

```ts
const pdfBuffer = await generateInvoicePdf(invoiceId)
const path = `invoices/${invoiceId}.pdf`

await supabaseAdmin.storage
  .from('documents')
  .upload(path, pdfBuffer, {
    contentType: 'application/pdf',
    upsert: true,
  })

// Get signed URL (30 day expiry for client download)
const { data: { signedUrl } } = await supabaseAdmin.storage
  .from('documents')
  .createSignedUrl(path, 60 * 60 * 24 * 30)
```
