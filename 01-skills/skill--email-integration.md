# Skill: email-integration

**Trigger:** Sending transactional emails — order confirmations, invoice delivery, password resets, notifications.
**Returns:** Resend, Nodemailer/Gmail, and React Email patterns for Next.js apps.

## Option Selection

| Need | Use |
|------|-----|
| Production transactional email | Resend (recommended) |
| Simple SMTP (internal tools) | Nodemailer + Gmail App Password |
| Complex email templates | React Email + Resend |
| Bulk/marketing email | Use a separate service (Mailchimp, etc.) |

## Resend — Recommended for Production

```typescript
// lib/email.ts
import { Resend } from 'resend'

const resend = new Resend(process.env.RESEND_API_KEY)

export async function sendInvoiceEmail(to: string, invoiceId: string, amount: number) {
  const { data, error } = await resend.emails.send({
    from: 'Jr\'s Auto Repair <invoices@jrsautorepair.com>',
    to,
    subject: `Invoice #${invoiceId} from Jr\'s Auto Repair`,
    html: `
      <h1>Invoice #${invoiceId}</h1>
      <p>Amount due: $${amount.toFixed(2)}</p>
      <p>View and pay: <a href="${process.env.NEXT_PUBLIC_URL}/invoice/${invoiceId}">Click here</a></p>
    `,
  })
  
  if (error) throw new Error(`Email failed: ${error.message}`)
  return data
}
```

## React Email — Reusable Templates

```typescript
// emails/InvoiceEmail.tsx
import { Html, Head, Body, Container, Text, Link, Button } from '@react-email/components'

interface InvoiceEmailProps {
  invoiceId: string
  amount: number
  customerName: string
  dueDate: string
}

export function InvoiceEmail({ invoiceId, amount, customerName, dueDate }: InvoiceEmailProps) {
  return (
    <Html>
      <Head />
      <Body style={{ fontFamily: 'sans-serif' }}>
        <Container>
          <Text>Hi {customerName},</Text>
          <Text>Invoice #{invoiceId} for ${amount.toFixed(2)} is due by {dueDate}.</Text>
          <Button href={`https://jrsautorepair.com/invoice/${invoiceId}`}>
            View Invoice
          </Button>
        </Container>
      </Body>
    </Html>
  )
}

// Sending with React Email + Resend:
import { render } from '@react-email/render'
const html = render(<InvoiceEmail {...props} />)
await resend.emails.send({ ..., html })
```

## Gmail SMTP (Simple / Internal Tools)

Used in silver-creek-logistics and jrs-auto-repair for simpler notifications:

```typescript
// lib/email.ts
import nodemailer from 'nodemailer'

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD,  // App Password, not Google account password
  },
})

export async function sendEmail({
  to,
  subject,
  html,
}: {
  to: string
  subject: string
  html: string
}) {
  await transporter.sendMail({
    from: `Jr's Auto Repair <${process.env.GMAIL_USER}>`,
    to,
    subject,
    html,
  })
}
```

**Getting Gmail App Password:**
1. Google Account → Security → 2-Step Verification (must be enabled)
2. Google Account → Security → App passwords → Create
3. Store as `GMAIL_APP_PASSWORD` (not the regular password)

## Error Handling

Email delivery is best-effort. Application logic should not block on email success:

```typescript
// Don't: await and fail the whole operation if email fails
await sendInvoiceEmail(to, invoiceId, amount)

// Do: fire and forget, log failure
sendInvoiceEmail(to, invoiceId, amount).catch(err => {
  console.error('Email notification failed (non-critical):', err)
})
```

For critical emails (password resets), do await and surface errors to the user.

## Template Variables Security

Never interpolate user-supplied content into HTML email without escaping:

```typescript
// Dangerous — XSS in email clients
const html = `<p>Hello ${req.body.name}</p>`

// Safe
import he from 'he'
const safeName = he.encode(req.body.name)
const html = `<p>Hello ${safeName}</p>`
```

Most email clients execute some JavaScript — XSS in email is a real attack vector.

## Env Variables

```
RESEND_API_KEY        # re_xxxx — from Resend dashboard
GMAIL_USER            # user@gmail.com
GMAIL_APP_PASSWORD    # 16-char app password (not regular password)
NEXT_PUBLIC_URL       # https://yoursite.com — for links in emails
```
