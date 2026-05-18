# Pattern: Printable Invoice

## Overview
Printable invoices have two different output targets: the browser's print dialog (via `@media print` CSS) and PDF export. Browser print is instant but styling is tricky — nav, buttons, and sidebars must hide, page breaks must be controlled, and multi-page layout must be tested. Server-side PDF generation (Puppeteer, React PDF, or a dedicated service) produces consistent output independent of browser print quirks and should be offered as an alternative.

## Implementation

### @media print stylesheet

```css
@media print {
  /* Hide everything that isn't invoice content */
  nav, header, footer, .sidebar, .print-hide, button, .toast {
    display: none !important;
  }

  /* Reset for print */
  body { background: white; color: black; font-size: 11pt; }
  a { color: black; text-decoration: none; }

  /* Invoice container fills the page */
  .invoice-container {
    max-width: 100%;
    padding: 0;
    margin: 0;
    box-shadow: none;
  }

  /* Don't break inside a line item */
  .invoice-line-item { page-break-inside: avoid; break-inside: avoid; }

  /* Keep the totals section together on one page */
  .invoice-totals { page-break-inside: avoid; break-inside: avoid; }

  /* Force page break before each invoice when printing multiple */
  .invoice-page-break { page-break-before: always; }
}
```

### Invoice React component

```tsx
function Invoice({ invoice }: { invoice: InvoiceData }) {
  const formatter = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })

  return (
    <div className="invoice-container max-w-3xl mx-auto p-8 bg-white">
      {/* Header */}
      <div className="flex justify-between items-start mb-8">
        <div>
          <h1 className="text-2xl font-bold">INVOICE</h1>
          <p className="text-gray-500">#{invoice.number}</p>
        </div>
        <div className="text-right">
          <p className="font-semibold">{invoice.company.name}</p>
          <p className="text-sm text-gray-600">{invoice.company.address}</p>
        </div>
      </div>

      {/* Bill to / dates */}
      <div className="grid grid-cols-2 gap-8 mb-8">
        <div>
          <p className="text-xs uppercase tracking-wider text-gray-400 mb-1">Bill To</p>
          <p className="font-semibold">{invoice.client.name}</p>
          <p className="text-sm text-gray-600">{invoice.client.address}</p>
        </div>
        <div className="text-right">
          <p className="text-sm">
            <span className="text-gray-400">Issue Date: </span>
            {formatDate(invoice.issuedAt)}
          </p>
          <p className="text-sm">
            <span className="text-gray-400">Due Date: </span>
            <span className={isOverdue(invoice.dueAt) ? 'text-red-600 font-medium' : ''}>
              {formatDate(invoice.dueAt)}
            </span>
          </p>
        </div>
      </div>

      {/* Line items */}
      <table className="w-full mb-8">
        <thead>
          <tr className="border-b-2 border-gray-200 text-left text-xs uppercase tracking-wider text-gray-400">
            <th className="py-2 pr-4">Description</th>
            <th className="py-2 pr-4 text-right">Qty</th>
            <th className="py-2 pr-4 text-right">Rate</th>
            <th className="py-2 text-right">Amount</th>
          </tr>
        </thead>
        <tbody>
          {invoice.lineItems.map((item) => (
            <tr key={item.id} className="invoice-line-item border-b border-gray-100">
              <td className="py-3 pr-4">{item.description}</td>
              <td className="py-3 pr-4 text-right">{item.quantity}</td>
              <td className="py-3 pr-4 text-right">{formatter.format(item.rate)}</td>
              <td className="py-3 text-right">{formatter.format(item.quantity * item.rate)}</td>
            </tr>
          ))}
        </tbody>
      </table>

      {/* Totals */}
      <div className="invoice-totals flex justify-end">
        <div className="w-64">
          <div className="flex justify-between py-1 text-sm">
            <span className="text-gray-500">Subtotal</span>
            <span>{formatter.format(invoice.subtotal)}</span>
          </div>
          {invoice.tax > 0 && (
            <div className="flex justify-between py-1 text-sm">
              <span className="text-gray-500">Tax ({invoice.taxRate}%)</span>
              <span>{formatter.format(invoice.tax)}</span>
            </div>
          )}
          <div className="flex justify-between py-2 font-bold text-lg border-t-2 border-gray-900 mt-1">
            <span>Total</span>
            <span>{formatter.format(invoice.total)}</span>
          </div>
        </div>
      </div>

      {/* Payment QR code */}
      {invoice.paymentUrl && (
        <div className="mt-8 flex items-center gap-4 p-4 border rounded-lg bg-gray-50">
          <QRCode value={invoice.paymentUrl} size={80} />
          <div>
            <p className="font-medium">Pay online</p>
            <p className="text-sm text-gray-500">Scan QR code or visit {invoice.paymentUrl}</p>
          </div>
        </div>
      )}
    </div>
  )
}
```

### Print and PDF buttons (hidden on print)

```tsx
function InvoiceActions({ invoiceId }: { invoiceId: string }) {
  const [generating, setGenerating] = useState(false)

  async function downloadPdf() {
    setGenerating(true)
    const res = await fetch(`/api/invoices/${invoiceId}/pdf`)
    const blob = await res.blob()
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `invoice-${invoiceId}.pdf`
    a.click()
    URL.revokeObjectURL(url)
    setGenerating(false)
  }

  return (
    <div className="print-hide flex gap-3">
      <Button variant="outline" onClick={() => window.print()}>
        <Printer size={16} /> Print
      </Button>
      <Button onClick={downloadPdf} disabled={generating}>
        <Download size={16} /> {generating ? 'Generating…' : 'Download PDF'}
      </Button>
    </div>
  )
}
```

### Server-side PDF (route handler using Puppeteer)

```ts
// app/api/invoices/[id]/pdf/route.ts
export async function GET(req: Request, { params }: { params: { id: string } }) {
  const browser = await puppeteer.launch({ headless: true })
  const page = await browser.newPage()

  // Render the invoice page with a server-only print token
  const invoiceUrl = `${process.env.NEXT_PUBLIC_URL}/invoices/${params.id}/print`
  await page.goto(invoiceUrl, { waitUntil: 'networkidle0' })

  const pdf = await page.pdf({
    format: 'Letter',
    printBackground: true,
    margin: { top: '0.5in', right: '0.5in', bottom: '0.5in', left: '0.5in' },
  })
  await browser.close()

  return new Response(pdf, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="invoice-${params.id}.pdf"`,
    },
  })
}
```

## Key Rules
- Use `@media print` CSS rather than a separate print route — single source of truth
- `page-break-inside: avoid` on line item rows prevents rows splitting across pages
- Currency should use `Intl.NumberFormat` — never manual `$` + `.toFixed(2)` (locale issues)
- Total amount should be the largest, most visually prominent element
- QR code linking to the payment URL removes friction for paper copies
- Server-side PDF generation produces consistent output across browsers and OS print dialogs
- Never use `window.print()` for automated PDF generation in pipelines — use Puppeteer or React PDF
- Test print layout at 8.5×11 and A4 if you have international clients
