# Email Templates with React Email

## Overview

React Email (`@react-email/components`) lets you write email templates as React components. Renders to HTML that works in Outlook, Gmail, Apple Mail, and others.

Used with Resend for delivery (see `plugin--resend.md`).

## Installation

```bash
npm install @react-email/components resend
```

## Basic Email Template

```typescript
// emails/InvoiceEmail.tsx
import {
  Html,
  Head,
  Preview,
  Body,
  Container,
  Section,
  Row,
  Column,
  Heading,
  Text,
  Link,
  Hr,
  Button,
} from '@react-email/components'

interface InvoiceEmailProps {
  customerName: string
  invoiceNumber: string
  total: number
  dueDate: string
  invoiceUrl: string
}

export function InvoiceEmail({
  customerName,
  invoiceNumber,
  total,
  dueDate,
  invoiceUrl,
}: InvoiceEmailProps) {
  return (
    <Html>
      <Head />
      <Preview>Invoice {invoiceNumber} from Jr.'s Auto Repair — ${total.toFixed(2)} due</Preview>
      <Body style={bodyStyle}>
        <Container style={containerStyle}>
          {/* Header */}
          <Section>
            <Heading style={h1Style}>Jr.'s Auto Repair</Heading>
          </Section>

          <Hr />

          {/* Content */}
          <Section>
            <Text>Hi {customerName},</Text>
            <Text>
              Your invoice <strong>{invoiceNumber}</strong> for{' '}
              <strong>${total.toFixed(2)}</strong> is ready.
            </Text>
            <Text>Due date: {dueDate}</Text>
          </Section>

          {/* CTA */}
          <Section style={{ textAlign: 'center', margin: '24px 0' }}>
            <Button href={invoiceUrl} style={buttonStyle}>
              View Invoice
            </Button>
          </Section>

          <Hr />

          {/* Footer */}
          <Section>
            <Text style={footerStyle}>
              Jr.'s Auto Repair · 417 Main Ave E, Twin Falls, ID · (208) 595-2101
            </Text>
          </Section>
        </Container>
      </Body>
    </Html>
  )
}

// Inline styles — required for email compatibility
const bodyStyle = {
  backgroundColor: '#f6f9fc',
  fontFamily: '-apple-system, sans-serif',
}

const containerStyle = {
  backgroundColor: '#ffffff',
  margin: '0 auto',
  padding: '20px',
  maxWidth: '600px',
}

const h1Style = {
  color: '#1a1a1a',
  fontSize: '24px',
}

const buttonStyle = {
  backgroundColor: '#1a1a1a',
  color: '#ffffff',
  padding: '12px 24px',
  borderRadius: '4px',
  textDecoration: 'none',
  display: 'inline-block',
}

const footerStyle = {
  color: '#6b7280',
  fontSize: '12px',
  textAlign: 'center' as const,
}
```

## Rendering to HTML

```typescript
import { render } from '@react-email/render'
import { InvoiceEmail } from '@/emails/InvoiceEmail'

const html = render(
  <InvoiceEmail
    customerName="Carlos"
    invoiceNumber="INV-2026-001"
    total={245.00}
    dueDate="June 1, 2026"
    invoiceUrl="https://jrsautorepair.worker-bee.app/invoice/abc123"
  />
)
```

## Sending with Resend

```typescript
import { Resend } from 'resend'
import { render } from '@react-email/render'
import { InvoiceEmail } from '@/emails/InvoiceEmail'

const resend = new Resend(process.env.RESEND_API_KEY)

export async function sendInvoiceEmail(invoice: Invoice, customer: Customer) {
  try {
    await resend.emails.send({
      from: 'billing@jrsautorepair.worker-bee.app',
      to: customer.email,
      subject: `Invoice ${invoice.number} — $${invoice.total.toFixed(2)}`,
      html: render(
        <InvoiceEmail
          customerName={customer.name}
          invoiceNumber={invoice.number}
          total={invoice.total}
          dueDate={formatDate(invoice.due_date)}
          invoiceUrl={`https://jrsautorepair.worker-bee.app/invoice/${invoice.id}`}
        />
      ),
    })
  } catch (error) {
    console.error('Invoice email failed:', error)
    // Don't throw — email failure shouldn't fail the invoice creation
  }
}
```

## Email-Safe CSS Rules

Email clients have very limited CSS support. Rules:
- Use `style` props with inline CSS (not Tailwind classes)
- No flexbox or grid — use `<Row>` and `<Column>` from React Email
- No `border-radius` > 4px (Outlook doesn't support it)
- No `position: absolute/fixed`
- Font stack should end with system fonts
- Images need explicit `width` and `height` attributes
- Links need `color` set explicitly (Outlook strips color)

## Preview During Development

```bash
npx email dev
# Opens email preview at http://localhost:3000
# Shows all templates in emails/ directory with live preview
```
