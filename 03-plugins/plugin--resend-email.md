# Resend Email

## Setup

```bash
npm install resend
```

```typescript
// lib/email.ts
import { Resend } from 'resend'

const resend = new Resend(process.env.RESEND_API_KEY)

// RESEND_API_KEY is server-only — never NEXT_PUBLIC_
```

## Basic Email Send

```typescript
export async function sendEmail({
  to,
  subject,
  html,
}: {
  to: string | string[]
  subject: string
  html: string
}): Promise<void> {
  const { error } = await resend.emails.send({
    from: 'Jr.\'s Auto Repair <invoices@jrsautorepair.com>',
    to: Array.isArray(to) ? to : [to],
    subject,
    html,
  })
  
  if (error) throw new Error(`Email send failed: ${error.message}`)
}
```

## React Email Templates

Use `@react-email/components` for type-safe HTML email templates:

```bash
npm install @react-email/components
```

```typescript
// emails/invoice-sent.tsx
import {
  Body, Container, Head, Heading, Html, Img,
  Preview, Section, Text, Button, Hr
} from '@react-email/components'
import { renderAsync } from '@react-email/render'

interface InvoiceSentEmailProps {
  customerName: string
  invoiceNumber: string
  totalAmount: string
  dueDate: string
  viewUrl: string
}

export function InvoiceSentEmail({
  customerName,
  invoiceNumber,
  totalAmount,
  dueDate,
  viewUrl,
}: InvoiceSentEmailProps) {
  return (
    <Html>
      <Head />
      <Preview>Invoice {invoiceNumber} — {totalAmount} due {dueDate}</Preview>
      <Body style={{ fontFamily: 'sans-serif', backgroundColor: '#f4f4f4' }}>
        <Container style={{ maxWidth: '600px', margin: '0 auto', padding: '20px' }}>
          <Heading>Invoice from Jr.'s Auto Repair</Heading>
          <Text>Hi {customerName},</Text>
          <Text>Your invoice {invoiceNumber} for {totalAmount} is due {dueDate}.</Text>
          <Section>
            <Button href={viewUrl} style={{ backgroundColor: '#2563eb', color: 'white', padding: '12px 24px', borderRadius: '4px' }}>
              View Invoice
            </Button>
          </Section>
          <Hr />
          <Text style={{ color: '#888', fontSize: '12px' }}>
            Jr.'s Auto Repair · 417 Main Ave E, Twin Falls, ID · (208) 595-2101
          </Text>
        </Container>
      </Body>
    </Html>
  )
}

// Render to HTML string:
export async function renderInvoiceSentEmail(props: InvoiceSentEmailProps): Promise<string> {
  return renderAsync(<InvoiceSentEmail {...props} />)
}
```

## Sending with Template

```typescript
// In Server Action:
export async function sendInvoice(invoiceId: string) {
  const invoice = await getInvoice(invoiceId)
  const customer = await getCustomer(invoice.customerId)
  
  const html = await renderInvoiceSentEmail({
    customerName: customer.name,
    invoiceNumber: invoice.number,
    totalAmount: formatCurrency(invoice.totalCents),
    dueDate: format(new Date(invoice.dueDate), 'MMMM d, yyyy'),
    viewUrl: `https://jrsautorepair.com/invoice/${invoice.publicToken}`,
  })
  
  await sendEmail({
    to: customer.email,
    subject: `Invoice ${invoice.number} from Jr.'s Auto Repair`,
    html,
  })
  
  await supabase
    .from('invoices')
    .update({ status: 'sent', sent_at: new Date().toISOString() })
    .eq('id', invoiceId)
}
```

## Environment Variables

```
RESEND_API_KEY=re_...
```

Set in Vercel dashboard under Environment Variables. Never commit to `.env.local` that's checked in.

## From Address Requirements

Resend requires a verified domain for the `from` address. Use the Resend dashboard to:
1. Add your domain
2. Verify DNS records (SPF, DKIM)
3. Use `name@yourdomain.com` as the from address

During development, use `onboarding@resend.dev` (Resend's default sandbox address) which works without domain verification.

## Error Handling

Email failure should not fail the primary operation:

```typescript
// In Server Action — email is secondary:
const invoice = await createInvoiceInDB(data)

// Non-blocking email:
sendInvoiceEmail(invoice).catch(e => {
  console.error('Failed to send invoice email:', invoice.id, e)
  // Optional: store failed email in DB for retry
})

return { success: true, data: invoice }
```
