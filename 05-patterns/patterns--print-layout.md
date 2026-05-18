# Pattern: Print Layout (Invoice / Report PDF)

## What This Solves

Print-ready pages and PDF-export via browser print need a separate visual treatment from the screen layout. The challenge is: hiding navigation/UI chrome, controlling page breaks, and ensuring the printed version matches the design. Two approaches: CSS print media queries (simple, free), and Playwright PDF generation (full control, programmatic).

## CSS Print Approach

```css
/* globals.css */
@media print {
  /* Hide everything except the printable area */
  nav, header, footer, .no-print, button, .sidebar {
    display: none !important;
  }

  body {
    background: white;
    color: black;
    font-size: 11pt;
  }

  /* Break control */
  .page-break-before { page-break-before: always; }
  .page-break-after { page-break-after: always; }
  .no-page-break { page-break-inside: avoid; }

  /* Reset shadows and borders for print */
  * {
    box-shadow: none !important;
    text-shadow: none !important;
  }

  a[href]::after {
    content: " (" attr(href) ")";
  }

  /* Show full URLs for links */
  a[href^="/"]:after {
    content: " (https://yoursite.com" attr(href) ")";
  }
}
```

## Invoice Print Component

```tsx
// components/PrintableInvoice.tsx
export function PrintableInvoice({ invoice }: { invoice: Invoice }) {
  return (
    <div className="print:block hidden" id="printable-invoice">
      {/* This div only renders in print mode */}
      <div className="p-8 max-w-2xl mx-auto">
        <div className="flex justify-between items-start mb-8">
          <div>
            <h1 className="text-2xl font-bold">{invoice.business_name}</h1>
            <p className="text-sm text-gray-600">{invoice.business_address}</p>
          </div>
          <div className="text-right">
            <h2 className="text-xl font-semibold">INVOICE</h2>
            <p className="text-sm">#{invoice.number}</p>
            <p className="text-sm">{format(new Date(invoice.issue_date), 'MMMM d, yyyy')}</p>
          </div>
        </div>

        {/* Line items */}
        <table className="w-full text-sm mb-8">
          <thead>
            <tr className="border-b border-gray-300">
              <th className="text-left py-2">Description</th>
              <th className="text-right py-2">Qty</th>
              <th className="text-right py-2">Rate</th>
              <th className="text-right py-2">Amount</th>
            </tr>
          </thead>
          <tbody>
            {invoice.items.map(item => (
              <tr key={item.id} className="border-b border-gray-100 no-page-break">
                <td className="py-2">{item.description}</td>
                <td className="text-right py-2">{item.quantity}</td>
                <td className="text-right py-2">${(item.unit_price_cents / 100).toFixed(2)}</td>
                <td className="text-right py-2">${(item.quantity * item.unit_price_cents / 100).toFixed(2)}</td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr className="font-bold">
              <td colSpan={3} className="text-right pt-4">Total</td>
              <td className="text-right pt-4">${(invoice.total_cents / 100).toFixed(2)}</td>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>
  )
}
```

## Print Button

```tsx
function PrintButton() {
  return (
    <Button
      onClick={() => window.print()}
      variant="outline"
      className="no-print"  // hidden in print mode itself
    >
      <Printer className="h-4 w-4 mr-2" />
      Print / Save PDF
    </Button>
  )
}
```

## Playwright PDF Generation (Programmatic)

For server-generated PDFs (email attachments, bulk export):

```ts
// lib/generate-invoice-pdf.ts
import playwright from 'playwright'

export async function generateInvoicePdf(invoiceId: string): Promise<Buffer> {
  const browser = await playwright.chromium.launch()
  const page = await browser.newPage()

  // Load the print-only page
  await page.goto(`${process.env.NEXT_PUBLIC_SITE_URL}/invoices/${invoiceId}/print`, {
    waitUntil: 'networkidle',
  })

  const pdf = await page.pdf({
    format: 'Letter',
    margin: { top: '1in', bottom: '1in', left: '1in', right: '1in' },
    printBackground: true,
  })

  await browser.close()
  return pdf
}
```

Route Handler to serve it:
```ts
export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const pdf = await generateInvoicePdf(id)

  return new NextResponse(pdf, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="invoice-${id}.pdf"`,
    },
  })
}
```

## @page CSS for Print

```css
@page {
  size: Letter;
  margin: 1in;
}

@page :first {
  margin-top: 0.75in;
}
```

## Key Rules

- Always test with browser print preview — Ctrl+P / Cmd+P
- Use `no-page-break` class on rows that must stay together
- Avoid fixed heights in print layout — let content determine height
- Use `pt` (points) not `px` for print font sizes
- Remove box-shadows and gradients for print — they often render poorly
