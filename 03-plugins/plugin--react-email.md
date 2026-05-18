# Plugin: React Email

## What It Is

React Email is a component library for building HTML emails using React. Works with Resend, Nodemailer, SendGrid, and any email provider. The output is static HTML — no client-side React runs in the email client.

## Installation

```bash
npm install react-email @react-email/components
# Also install the Resend SDK if sending via Resend
npm install resend
```

## Core Components

| Component | Purpose |
|-----------|---------|
| `Html` | Root wrapper; sets lang |
| `Head` | `<head>` meta tags |
| `Body` | Sets background, font-family |
| `Container` | Max-width centered container |
| `Section` | Block-level grouping |
| `Row` + `Column` | Table-based columns (email layout) |
| `Text` | `<p>` with line-height |
| `Heading` | `<h1>`–`<h6>` |
| `Button` | Styled CTA link (renders as `<a>`) |
| `Link` | Inline anchor |
| `Img` | `<img>` with required width/height |
| `Hr` | Divider line |
| `Preview` | Preview text shown in inbox list |

## Basic Invoice Email

```tsx
// emails/invoice.tsx
import {
  Html, Head, Body, Container, Section,
  Text, Heading, Button, Hr, Preview
} from '@react-email/components'

interface InvoiceEmailProps {
  clientName: string
  invoiceNumber: string
  totalCents: number
  dueDate: string
  paymentUrl: string
}

export function InvoiceEmail({
  clientName,
  invoiceNumber,
  totalCents,
  dueDate,
  paymentUrl,
}: InvoiceEmailProps) {
  const total = (totalCents / 100).toFixed(2)

  return (
    <Html lang="en">
      <Head />
      <Preview>Invoice #{invoiceNumber} — ${total} due {dueDate}</Preview>
      <Body style={{ backgroundColor: '#f6f9fc', fontFamily: 'sans-serif' }}>
        <Container style={{ maxWidth: '600px', margin: '0 auto', padding: '20px' }}>
          <Heading style={{ color: '#1a1a1a' }}>Invoice #{invoiceNumber}</Heading>
          <Text>Hi {clientName},</Text>
          <Text>
            Your invoice for ${total} is due on {dueDate}.
          </Text>
          <Section style={{ textAlign: 'center', margin: '32px 0' }}>
            <Button
              href={paymentUrl}
              style={{
                backgroundColor: '#2563eb',
                color: '#fff',
                padding: '12px 24px',
                borderRadius: '6px',
              }}
            >
              Pay Invoice
            </Button>
          </Section>
          <Hr />
          <Text style={{ color: '#666', fontSize: '14px' }}>
            Questions? Call (208) 595-2101
          </Text>
        </Container>
      </Body>
    </Html>
  )
}

export default InvoiceEmail
```

## Rendering and Sending

```ts
// lib/email/send-invoice.ts
import { render } from '@react-email/render'
import { Resend } from 'resend'
import { InvoiceEmail } from '@/emails/invoice'

const resend = new Resend(process.env.RESEND_API_KEY)

export async function sendInvoiceEmail(params: {
  to: string
  clientName: string
  invoiceNumber: string
  totalCents: number
  dueDate: string
  paymentUrl: string
}) {
  const html = await render(
    <InvoiceEmail
      clientName={params.clientName}
      invoiceNumber={params.invoiceNumber}
      totalCents={params.totalCents}
      dueDate={params.dueDate}
      paymentUrl={params.paymentUrl}
    />
  )

  const { data, error } = await resend.emails.send({
    from: 'invoices@jrsautorepair.com',
    to: params.to,
    subject: `Invoice #${params.invoiceNumber}`,
    html,
  })

  if (error) throw new Error(`Email failed: ${error.message}`)
  return data
}
```

## Preview During Development

```bash
npx email dev --dir emails --port 3030
# Opens browser preview of all email templates
```

Access at `http://localhost:3030` — shows live-rendered HTML with props.

## Inline Styles Required

Email clients ignore `<style>` tags and CSS classes. All styles must be inline:

```tsx
// WRONG — CSS classes don't work in emails
<Text className="text-gray-600 text-sm">

// CORRECT — inline styles only
<Text style={{ color: '#666', fontSize: '14px' }}>
```

React Email applies styles inline automatically — use `style={{}}` objects, not Tailwind classes.

## Using with Tailwind (Experimental)

```tsx
import { Tailwind } from '@react-email/tailwind'

export function WelcomeEmail() {
  return (
    <Tailwind>
      <Body className="bg-gray-100">
        <Text className="text-gray-800">Welcome!</Text>
      </Body>
    </Tailwind>
  )
}
```

`@react-email/tailwind` inlines Tailwind styles at render time. Not all utilities work — prefer explicit style objects for critical layout.

## Image Hosting

Images must be absolute URLs — no relative paths in emails:

```tsx
// WRONG
<Img src="/logo.png" />

// CORRECT
<Img
  src="https://yourdomain.com/logo.png"
  width="120"
  height="40"
  alt="Logo"
/>
```

Always specify `width` and `height` — prevents layout shift in email clients.

## Fallbacks for Email Clients

```tsx
// Table-based two-column layout (most compatible)
<Row>
  <Column style={{ width: '50%', paddingRight: '8px' }}>
    Left content
  </Column>
  <Column style={{ width: '50%', paddingLeft: '8px' }}>
    Right content
  </Column>
</Row>
```

## Testing Across Clients

Use [Litmus](https://litmus.com) or [Email on Acid](https://www.emailonacid.com) before sending to production lists. Gmail, Outlook, Apple Mail, and mobile all render differently. Test dark mode — many email clients now support `prefers-color-scheme`.
