# Plugin: Nodemailer

## What It Is

Nodemailer sends emails via SMTP from Node.js. Used for: Gmail app passwords, custom SMTP servers, transactional email without a third-party API. Alternative to Resend/SendGrid when you have existing SMTP credentials or need to use Gmail.

## Installation

```bash
npm install nodemailer
npm install --save-dev @types/nodemailer
```

## Gmail via App Password (silver-creek-logistics pattern)

```ts
// lib/email.ts
import 'server-only'
import nodemailer from 'nodemailer'

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER!,        // full gmail address
    pass: process.env.GMAIL_APP_PASSWORD!, // App password (not account password)
  },
})

export async function sendEmail({
  to,
  subject,
  html,
  text,
}: {
  to: string | string[]
  subject: string
  html?: string
  text?: string
}) {
  const info = await transporter.sendMail({
    from: `"JR's Auto Repair" <${process.env.GMAIL_USER}>`,
    to: Array.isArray(to) ? to.join(', ') : to,
    subject,
    html,
    text,
  })

  return info.messageId
}
```

**Gmail App Password setup:**
1. Google Account → Security → 2-Step Verification → App passwords
2. Create a new app password (16 characters, no spaces)
3. Store as `GMAIL_APP_PASSWORD` env var

Never use your actual Gmail password — it won't work and is insecure.

## Generic SMTP

```ts
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST!,      // 'smtp.mailgun.org'
  port: parseInt(process.env.SMTP_PORT ?? '587'),
  secure: false,  // true for 465, false for 587 (STARTTLS)
  auth: {
    user: process.env.SMTP_USER!,
    pass: process.env.SMTP_PASS!,
  },
})
```

Port 587 + `secure: false` uses STARTTLS (upgrades connection). Port 465 + `secure: true` uses SSL/TLS from start.

## HTML Email with Template

```ts
export async function sendInvoiceEmail(invoice: Invoice) {
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: Arial, sans-serif; }
        .btn { background: #2563eb; color: #fff; padding: 12px 24px; text-decoration: none; border-radius: 6px; }
      </style>
    </head>
    <body>
      <h2>Invoice #${invoice.number}</h2>
      <p>Hi ${invoice.client_name},</p>
      <p>Your invoice for $${(invoice.total_cents / 100).toFixed(2)} is due on ${invoice.due_date}.</p>
      <p><a class="btn" href="${invoice.payment_url}">Pay Invoice</a></p>
    </body>
    </html>
  `

  await sendEmail({
    to: invoice.client_email,
    subject: `Invoice #${invoice.number} from JR's Auto Repair`,
    html,
  })
}
```

## Attachment

```ts
await transporter.sendMail({
  from: process.env.GMAIL_USER,
  to: 'client@example.com',
  subject: 'Invoice attached',
  text: 'Please find your invoice attached.',
  attachments: [
    {
      filename: 'invoice-1042.pdf',
      content: pdfBuffer,        // Buffer
      contentType: 'application/pdf',
    },
    {
      filename: 'logo.png',
      path: '/path/to/logo.png', // File path (local)
      cid: 'logo@company',       // Content-ID (for inline images: <img src="cid:logo@company">)
    },
  ],
})
```

## Testing Without Sending (Ethereal)

```ts
// In development: create a test account that captures emails without sending
const testAccount = await nodemailer.createTestAccount()

const devTransporter = nodemailer.createTransport({
  host: 'smtp.ethereal.email',
  port: 587,
  auth: {
    user: testAccount.user,
    pass: testAccount.pass,
  },
})

const info = await devTransporter.sendMail({
  from: 'test@example.com',
  to: 'recipient@example.com',
  subject: 'Test',
  text: 'This is a test email',
})

// View the email at this URL
console.log('Preview URL:', nodemailer.getTestMessageUrl(info))
```

## When to Use Nodemailer vs Resend

| | Nodemailer | Resend |
|--|------------|--------|
| Setup | Configure SMTP | Add API key |
| Deliverability | Depends on SMTP provider | High (Resend handles) |
| Analytics | None | Open/click tracking |
| Volume | Unlimited (SMTP quota) | 3k/month free |
| Best for | Existing SMTP, Gmail | New projects |

Use Resend for new projects. Use Nodemailer when: you already have Gmail/SMTP credentials, the client uses their existing email, or you're integrating with a custom mail server.
