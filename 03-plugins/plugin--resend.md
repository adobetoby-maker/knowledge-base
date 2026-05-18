# Resend Email Integration

## Setup

```bash
npm install resend
```

```typescript
// lib/email.ts
import { Resend } from 'resend'

const resend = new Resend(process.env.RESEND_API_KEY)

export { resend }
```

Env var: `RESEND_API_KEY` (server-only, no `NEXT_PUBLIC_` prefix).

Domain must be verified in Resend dashboard before sending from custom domain. `From` address must match verified domain.

## Basic Text Email

```typescript
import { resend } from '@/lib/email'

export async function sendWelcomeEmail(to: string, name: string) {
  const { data, error } = await resend.emails.send({
    from: "Jr.'s Auto Repair <noreply@jrsautorepair.worker-bee.app>",
    to,
    subject: "Welcome to Jr.'s Auto Repair",
    text: `Hi ${name}, thanks for joining our service reminder list. We'll reach out when it's time for your next service.`,
  })
  
  if (error) {
    console.error('Email send failed:', error.message)
    // Email is non-critical — don't throw, don't fail the main operation
  }
}
```

## React Email Templates

React Email lets you build email templates as React components:

```bash
npm install @react-email/components react-email
```

```typescript
// emails/invoice-created.tsx
import {
  Html, Head, Body, Container, Heading, Text, Button, Hr, Section,
} from '@react-email/components'

interface InvoiceCreatedEmailProps {
  customerName: string
  invoiceNumber: string
  amount: number
  viewUrl: string
}

export function InvoiceCreatedEmail({
  customerName,
  invoiceNumber,
  amount,
  viewUrl,
}: InvoiceCreatedEmailProps) {
  return (
    <Html>
      <Head />
      <Body style={{ fontFamily: 'Arial, sans-serif', background: '#f9fafb' }}>
        <Container style={{ maxWidth: '560px', margin: '0 auto', padding: '40px 20px' }}>
          <Heading style={{ color: '#111', fontSize: '24px' }}>
            Your Invoice is Ready
          </Heading>
          <Text>Hi {customerName},</Text>
          <Text>
            Invoice #{invoiceNumber} for ${amount.toFixed(2)} has been created for your recent service.
          </Text>
          <Section style={{ textAlign: 'center', margin: '32px 0' }}>
            <Button
              href={viewUrl}
              style={{
                background: '#2563eb',
                color: '#fff',
                padding: '12px 24px',
                borderRadius: '6px',
                textDecoration: 'none',
              }}
            >
              View Invoice
            </Button>
          </Section>
          <Hr />
          <Text style={{ color: '#6b7280', fontSize: '14px' }}>
            Jr.'s Auto Repair · 417 Main Ave E, Twin Falls, ID · (208) 595-2101
          </Text>
        </Container>
      </Body>
    </Html>
  )
}
```

## Sending React Email Template

```typescript
import { render } from '@react-email/render'
import { InvoiceCreatedEmail } from '@/emails/invoice-created'

export async function sendInvoiceEmail(invoice: Invoice, customer: Customer) {
  const html = await render(
    InvoiceCreatedEmail({
      customerName: customer.name,
      invoiceNumber: invoice.number,
      amount: invoice.total,
      viewUrl: `https://jrsautorepair.worker-bee.app/invoice/${invoice.public_token}`,
    })
  )
  
  await resend.emails.send({
    from: "Jr.'s Auto Repair <noreply@jrsautorepair.worker-bee.app>",
    to: customer.email,
    subject: `Invoice #${invoice.number} — Jr.'s Auto Repair`,
    html,
  })
}
```

## Email in Server Actions

```typescript
// app/actions/invoices.ts
'use server'
import { sendInvoiceEmail } from '@/lib/email'

export async function createAndSendInvoice(formData: FormData) {
  const invoice = await createInvoice(formData)
  
  // Non-critical: email failure should not fail the invoice creation
  try {
    await sendInvoiceEmail(invoice, invoice.customer)
  } catch (err) {
    console.error('Email notification failed:', err)
    // Invoice was created successfully — don't surface email failure to user
  }
  
  revalidatePath('/admin/invoices')
  return invoice
}
```

## Development Testing

Resend provides `onboarding@resend.dev` as a verified from-address for testing. Use your personal email as the recipient to test without domain verification.

In development, consider logging emails instead of sending:

```typescript
async function sendEmail(opts: EmailOptions) {
  if (process.env.NODE_ENV === 'development') {
    console.log('[EMAIL]', { to: opts.to, subject: opts.subject })
    return
  }
  await resend.emails.send(opts)
}
```

## Rate Limits

Resend free tier: 100 emails/day, 3,000/month. Paid tiers for higher volume.

Never call Resend in a loop without rate limiting:
```typescript
// WRONG — may exceed rate limits
for (const customer of customers) {
  await sendReminderEmail(customer)
}

// BETTER — with delay
for (const customer of customers) {
  await sendReminderEmail(customer)
  await new Promise(r => setTimeout(r, 100))  // 10/sec max
}
```
