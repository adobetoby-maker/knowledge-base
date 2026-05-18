# Batch: Invoice Generation

## Overview

Automated invoice generation runs at billing cycle end: collect line items, calculate totals (with tax), generate a PDF, store it, and email it. The key invariant: invoices are immutable once issued — never modify a sent invoice, issue a credit note instead.

## Invoice Schema

```sql
CREATE TABLE invoices (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  number        text NOT NULL UNIQUE,  -- INV-2026-0042
  user_id       uuid NOT NULL REFERENCES users(id),
  status        text NOT NULL DEFAULT 'draft',  -- draft, issued, paid, void
  subtotal_cents bigint NOT NULL,
  tax_cents      bigint NOT NULL DEFAULT 0,
  total_cents    bigint NOT NULL,
  currency      text NOT NULL DEFAULT 'USD',
  issued_at     timestamptz,
  due_at        timestamptz,
  paid_at       timestamptz,
  pdf_url       text,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE invoice_line_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id    uuid NOT NULL REFERENCES invoices(id),
  description   text NOT NULL,
  quantity      int NOT NULL DEFAULT 1,
  unit_price_cents bigint NOT NULL,
  total_cents   bigint GENERATED ALWAYS AS (quantity * unit_price_cents) STORED
);

-- Sequential invoice number
CREATE SEQUENCE invoice_number_seq START 1;
```

## Invoice Number Generation

```ts
async function generateInvoiceNumber(): Promise<string> {
  const year = new Date().getFullYear()
  const seq = await db.execute(sql`SELECT nextval('invoice_number_seq') AS n`)
  const n = String((seq.rows[0] as { n: number }).n).padStart(4, '0')
  return `INV-${year}-${n}`
}
```

## Building the Invoice

```ts
async function generateInvoiceForUser(userId: string, periodEnd: Date): Promise<string> {
  const user = await db.query.users.findFirst({ where: eq(users.id, userId) })
  if (!user) throw new Error('User not found')

  // Collect billable items from the period
  const usageItems = await db.select()
    .from(usageEvents)
    .where(
      and(
        eq(usageEvents.userId, userId),
        lte(usageEvents.occurredAt, periodEnd),
        isNull(usageEvents.invoiceId),  // Not yet invoiced
      )
    )

  if (usageItems.length === 0) return null  // Nothing to bill

  const lineItems = usageItems.map(item => ({
    description: item.description,
    quantity: item.quantity,
    unitPriceCents: item.unitPriceCents,
  }))

  const subtotalCents = lineItems.reduce((sum, item) =>
    sum + item.quantity * item.unitPriceCents, 0)

  // Calculate tax based on user's billing address
  const taxRate = getTaxRate(user.country, user.state)
  const taxCents = Math.round(subtotalCents * taxRate)
  const totalCents = subtotalCents + taxCents

  const invoiceNumber = await generateInvoiceNumber()

  const [invoice] = await db.insert(invoices).values({
    number: invoiceNumber,
    userId,
    status: 'draft',
    subtotalCents,
    taxCents,
    totalCents,
    issuedAt: new Date(),
    dueAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),  // Net 30
  }).returning()

  await db.insert(invoiceLineItems).values(
    lineItems.map(item => ({ ...item, invoiceId: invoice.id }))
  )

  // Mark usage items as invoiced
  await db.update(usageEvents)
    .set({ invoiceId: invoice.id })
    .where(inArray(usageEvents.id, usageItems.map(u => u.id)))

  return invoice.id
}
```

## PDF Generation with React Email + Puppeteer

```ts
import puppeteer from 'puppeteer'
import { renderToStaticMarkup } from 'react-dom/server'

async function generateInvoicePdf(invoiceId: string): Promise<Buffer> {
  const invoice = await getInvoiceWithItems(invoiceId)
  const html = renderToStaticMarkup(<InvoiceTemplate invoice={invoice} />)

  const browser = await puppeteer.launch({ headless: true })
  const page = await browser.newPage()
  await page.setContent(`<!DOCTYPE html>${html}`, { waitUntil: 'networkidle0' })

  const pdf = await page.pdf({
    format: 'A4',
    printBackground: true,
    margin: { top: '20mm', right: '20mm', bottom: '20mm', left: '20mm' },
  })

  await browser.close()
  return pdf
}
```

For serverless environments, use `@sparticuz/chromium` (a stripped-down Chromium for Lambda/Vercel).

## Issue and Email

```ts
async function issueInvoice(invoiceId: string) {
  const pdf = await generateInvoicePdf(invoiceId)

  // Upload PDF
  const filename = `invoices/${invoiceId}.pdf`
  await supabaseAdmin.storage.from('billing').upload(filename, pdf, {
    contentType: 'application/pdf',
  })
  const { data: { publicUrl } } = supabaseAdmin.storage.from('billing').getPublicUrl(filename)

  // Mark as issued and store PDF URL
  await db.update(invoices)
    .set({ status: 'issued', pdfUrl: publicUrl, issuedAt: new Date() })
    .where(eq(invoices.id, invoiceId))

  // Email the invoice
  const invoice = await getInvoiceWithItems(invoiceId)
  await resend.emails.send({
    to: invoice.user.email,
    subject: `Invoice ${invoice.number} — $${(invoice.totalCents / 100).toFixed(2)}`,
    attachments: [{ filename: `${invoice.number}.pdf`, content: pdf }],
    react: <InvoiceEmailTemplate invoice={invoice} />,
  })
}
```

## Key Rules

- Invoices are immutable once issued — never UPDATE a sent invoice; issue a credit note (negative invoice) to correct errors.
- Tax calculation must happen at invoice time — tax rates change, and the rate on the invoice date is the correct rate.
- Sequential invoice numbers using a DB sequence are required for accounting compliance in most jurisdictions.
- Generate PDF from HTML (React Email + Puppeteer) rather than a PDF library — HTML templates are easier to maintain.
- Mark billable items as invoiced atomically with creating the invoice — prevents double-billing on retry.
